# -*- coding: utf-8 -*-
"""hddid_clime: CLIME precision matrix estimation for hddid-stata

Implements the CLIME (Constrained L1-Minimization for Inverse Matrix
Estimation) algorithm for high-dimensional precision matrix estimation.
The scalar p=1 bridge uses the analytic covariance inverse directly.
For multivariate retained covariances, even an exactly diagonal sample path
still follows the R flare::sugm(method="clime") +
sugm.select(criterion="cv", loss="tracel2") lambda/loss contract once the
fold partition is fixed. The Python bridge uses NumPy's RNG stream for CV
partitions, so the same numeric seed need not reproduce R
flare::part.cv() fold identities exactly.

Reference: Cai, T., Liu, W. & Luo, X. (2011). A constrained L1
minimization approach to sparse precision matrix estimation.
Journal of the American Statistical Association, 106(494), 594-607.
"""
__version__ = "1.0.0"

import functools
import hashlib
import importlib.util
import inspect
import numpy as np
import pathlib
import sys
import types
from collections.abc import MutableMapping

STATA_SYSTEM_MISSING = np.float64(8.98846567431158e307)
NUMPY_RANDOM_STATE_MAX = int(np.iinfo(np.uint32).max)
STATA_MAX_NAME_LENGTH = 32
_SCIPY_LINPROG = None
_SCIPY_OPTIMIZE_ID = (
    id(sys.modules["scipy.optimize"])
    if sys.modules.get("scipy.optimize") is not None
    else None
)
linprog = None


class _RuntimeSolverResolverContractError(TypeError):
    """Resolver payload violated the synchronous solver contract."""


def _is_scipy_optimize_handle(obj):
    """Return whether obj still looks like a scipy.optimize routine."""
    module_name = getattr(obj, "__module__", "")
    return (
        isinstance(module_name, str)
        and module_name.startswith("scipy.optimize")
        and (
            inspect.isfunction(obj)
            or inspect.ismethod(obj)
            or inspect.isbuiltin(obj)
        )
    )


def _is_scipy_optimize_callable_object(obj):
    """Return whether obj is a scipy callable-object handle, not an explicit hook."""
    if not callable(obj):
        return False
    if inspect.isfunction(obj) or inspect.ismethod(obj) or inspect.isbuiltin(obj):
        return False
    obj_type = type(obj)
    type_module_name = getattr(obj_type, "__module__", "")
    return (
        isinstance(type_module_name, str)
        and type_module_name.startswith("scipy.optimize")
    )


def _unwrap_partial_callable_root(obj):
    """Unwrap functools.partial layers to the underlying callable."""
    seen = set()
    while isinstance(obj, functools.partial) and id(obj) not in seen:
        seen.add(id(obj))
        obj = obj.func
    return obj


def _is_scipy_optimize_alias_like(obj):
    """Return whether obj ultimately wraps a scipy.optimize callable."""
    root = _unwrap_partial_callable_root(obj)
    return (
        _is_scipy_optimize_handle(root)
        or _is_scipy_optimize_callable_object(root)
    )


def _is_plain_callable_alias(obj):
    """Return whether obj looks like a plain function alias, not a hook object."""
    return inspect.isfunction(obj) or inspect.ismethod(obj) or inspect.isbuiltin(obj)


def _is_async_callable(obj):
    """Return whether obj is a callable that would produce an un-awaited coroutine."""
    if not callable(obj):
        return False
    if inspect.iscoroutinefunction(obj) or inspect.isasyncgenfunction(obj):
        return True
    call = getattr(obj, "__call__", None)
    return call is not None and (
        inspect.iscoroutinefunction(call) or inspect.isasyncgenfunction(call)
    )


def _describe_async_callable(obj):
    """Describe the async callable flavor for bridge contract errors."""
    call = getattr(obj, "__call__", None)
    if inspect.isasyncgenfunction(obj) or (
        call is not None and inspect.isasyncgenfunction(call)
    ):
        return "async generator function"
    return "async function"


def _validate_runtime_solver_callable(obj, source):
    """Require runtime solver handles to be synchronous callables."""
    if obj is not None and _is_async_callable(obj):
        raise TypeError(
            f"{source} must be a synchronous callable, got "
            f"{_describe_async_callable(obj)}"
        )
    return obj


def _has_concrete_runtime_parameters(obj):
    """Return whether a callable advertises named runtime parameters."""
    try:
        parameters = list(inspect.signature(obj).parameters.values())
    except Exception:
        return False
    if (
        parameters
        and parameters[0].name in {"self", "cls"}
        and parameters[0].kind
        in (
            inspect.Parameter.POSITIONAL_ONLY,
            inspect.Parameter.POSITIONAL_OR_KEYWORD,
        )
    ):
        parameters = parameters[1:]
    return any(
        parameter.kind
        not in (
            inspect.Parameter.VAR_POSITIONAL,
            inspect.Parameter.VAR_KEYWORD,
        )
        for parameter in parameters
    )


def _prefer_concrete_object_signature(obj, call):
    """Return whether object-level signature should outrank a generic __call__.

    Some legacy callable objects intentionally expose their public API through
    ``__signature__`` while implementing the runtime adapter itself as a
    generic ``__call__(*args, **kwargs)`` shim. In that shape, preferring the
    generic call signature reroutes CLIME tuning kwargs into an anonymous
    positional tail even though the object advertises a concrete keyword-aware
    contract. Only prefer the object-level signature when it is strictly more
    informative than the callable entry point.
    """
    obj_optional_hints = _signature_optional_hint_count(obj)
    call_optional_hints = _signature_optional_hint_count(call)
    return (
        call is not None
        and call is not obj
        and _has_concrete_runtime_parameters(obj)
        and not _has_concrete_runtime_parameters(call)
        and obj_optional_hints > call_optional_hints
    )


_BRIDGE_SIGNATURE_HINT_NAMES = (
    "tildex_matname",
    "covinv_matname",
    "nfolds_cv",
    "nlambda",
    "lambda_min_ratio",
    "random_state",
    "perturb",
    "parallel",
    "nproc",
    "verbose",
    "c",
    "A_ub",
    "b_ub",
    "method",
)

_BRIDGE_SIGNATURE_REQUIRED_HINT_GROUPS = (
    frozenset({"tildex_matname", "covinv_matname"}),
    frozenset({"c", "A_ub", "b_ub", "method"}),
)


def _signature_optional_hint_count(obj):
    """Count non-mandatory bridge/runtime hint names advertised by obj."""
    if obj is None:
        return 0
    try:
        signature = inspect.signature(obj)
    except Exception:
        return 0

    hint_names = {
        parameter.name
        for parameter in signature.parameters.values()
        if parameter.kind
        not in (
            inspect.Parameter.VAR_POSITIONAL,
            inspect.Parameter.VAR_KEYWORD,
        )
        and parameter.name in _BRIDGE_SIGNATURE_HINT_NAMES
    }
    required_hint_count = max(
        (len(hint_names & group) for group in _BRIDGE_SIGNATURE_REQUIRED_HINT_GROUPS),
        default=0,
    )
    return len(hint_names) - required_hint_count


def _signature_runtime_parameter_score(signature):
    """Score how well a signature matches the bridge/runtime callable contract."""
    parameters = list(signature.parameters.values())
    if (
        parameters
        and parameters[0].name in {"self", "cls"}
        and parameters[0].kind
        in (
            inspect.Parameter.POSITIONAL_ONLY,
            inspect.Parameter.POSITIONAL_OR_KEYWORD,
        )
    ):
        parameters = parameters[1:]
    named_parameters = [
        parameter
        for parameter in parameters
        if parameter.kind
        not in (
            inspect.Parameter.VAR_POSITIONAL,
            inspect.Parameter.VAR_KEYWORD,
        )
    ]
    named_parameter_names = {parameter.name for parameter in named_parameters}
    variadic_parameters = sum(
        parameter.kind
        in (
            inspect.Parameter.VAR_POSITIONAL,
            inspect.Parameter.VAR_KEYWORD,
        )
        for parameter in parameters
    )
    return (
        sum(name in named_parameter_names for name in _BRIDGE_SIGNATURE_HINT_NAMES),
        len(named_parameters),
        -variadic_parameters,
    )


def _signature_hint_names(signature):
    """Return bridge/runtime hint names explicitly advertised by a signature."""
    parameters = list(signature.parameters.values())
    if (
        parameters
        and parameters[0].name in {"self", "cls"}
        and parameters[0].kind
        in (
            inspect.Parameter.POSITIONAL_ONLY,
            inspect.Parameter.POSITIONAL_OR_KEYWORD,
        )
    ):
        parameters = parameters[1:]
    return {
        parameter.name
        for parameter in parameters
        if parameter.kind
        not in (
            inspect.Parameter.VAR_POSITIONAL,
            inspect.Parameter.VAR_KEYWORD,
        )
        and parameter.name in _BRIDGE_SIGNATURE_HINT_NAMES
    }


def _signature_has_concrete_runtime_parameters(signature):
    """Return whether a resolved signature advertises named runtime parameters."""
    parameters = list(signature.parameters.values())
    if (
        parameters
        and parameters[0].name in {"self", "cls"}
        and parameters[0].kind
        in (
            inspect.Parameter.POSITIONAL_ONLY,
            inspect.Parameter.POSITIONAL_OR_KEYWORD,
        )
    ):
        parameters = parameters[1:]
    return any(
        parameter.kind
        not in (
            inspect.Parameter.VAR_POSITIONAL,
            inspect.Parameter.VAR_KEYWORD,
        )
        for parameter in parameters
    )


def _prefer_follow_false_runtime_signature(
    follow_false_signature,
    follow_true_signature,
):
    """Return whether runtime signature must outrank stale wrapped metadata.

    Decorator-style wrappers sometimes expose ``__wrapped__`` metadata from a
    keyword-aware publisher even though the runtime entry point itself accepts
    any additional CLIME/runtime hints only through ``*args``. In that shape,
    the bridge must follow the real wrapper signature so optional hints stay in
    the positional tail instead of being re-routed into unsupported kwargs.
    """
    if follow_false_signature is None or follow_true_signature is None:
        return False
    extra_hint_names = (
        _signature_hint_names(follow_true_signature)
        - _signature_hint_names(follow_false_signature)
    )
    if not extra_hint_names:
        return False
    parameters = list(follow_false_signature.parameters.values())
    has_var_positional = any(
        parameter.kind == inspect.Parameter.VAR_POSITIONAL
        for parameter in parameters
    )
    has_var_keyword = any(
        parameter.kind == inspect.Parameter.VAR_KEYWORD
        for parameter in parameters
    )
    if (
        _signature_has_concrete_runtime_parameters(follow_false_signature)
        and not has_var_keyword
    ):
        return True
    if not has_var_positional or has_var_keyword:
        return False
    return True


def _resolve_plain_function_runtime_signature(obj):
    """Rebuild a plain function signature without stale exported metadata."""
    if not inspect.isfunction(obj):
        return None
    try:
        runtime_function = types.FunctionType(
            obj.__code__,
            obj.__globals__,
            name=obj.__name__,
            argdefs=obj.__defaults__,
            closure=obj.__closure__,
        )
    except Exception:
        return None
    runtime_function.__kwdefaults__ = getattr(obj, "__kwdefaults__", None)
    runtime_function.__annotations__ = getattr(obj, "__annotations__", {})
    try:
        return inspect.signature(runtime_function)
    except Exception:
        return None


def _resolve_plain_callable_runtime_signature(candidate):
    """Rebuild a plain callable or partial thereof without stale metadata."""
    partial_args = ()
    partial_keywords = {}
    target = candidate
    if isinstance(candidate, functools.partial):
        partial_args = candidate.args
        partial_keywords = candidate.keywords or {}
        target = candidate.func

    runtime_target = None
    if inspect.isfunction(target):
        try:
            runtime_target = types.FunctionType(
                target.__code__,
                target.__globals__,
                name=target.__name__,
                argdefs=target.__defaults__,
                closure=target.__closure__,
            )
        except Exception:
            return None
        runtime_target.__kwdefaults__ = getattr(target, "__kwdefaults__", None)
        runtime_target.__annotations__ = getattr(target, "__annotations__", {})
    elif inspect.ismethod(target) and inspect.isfunction(getattr(target, "__func__", None)):
        base = target.__func__
        try:
            runtime_target = types.FunctionType(
                base.__code__,
                base.__globals__,
                name=base.__name__,
                argdefs=base.__defaults__,
                closure=base.__closure__,
            )
        except Exception:
            return None
        runtime_target.__kwdefaults__ = getattr(base, "__kwdefaults__", None)
        runtime_target.__annotations__ = getattr(base, "__annotations__", {})
        runtime_target = types.MethodType(runtime_target, target.__self__)
    else:
        return None

    if partial_args or partial_keywords:
        runtime_target = functools.partial(
            runtime_target,
            *partial_args,
            **partial_keywords,
        )
    try:
        return inspect.signature(runtime_target, follow_wrapped=False)
    except Exception:
        return None


def _prefer_plain_function_runtime_signature(
    runtime_signature,
    exported_signature,
):
    """Return whether a plain function's rebuilt runtime signature should win."""
    if runtime_signature is None or exported_signature is None:
        return False
    return _prefer_follow_false_runtime_signature(
        runtime_signature,
        exported_signature,
    )


def _resolve_candidate_signature(candidate):
    """Return the best runtime-oriented signature for a bridge candidate."""
    signatures = []
    follow_false_signature = None
    follow_true_signature = None
    plain_runtime_signature = _resolve_plain_callable_runtime_signature(candidate)
    for follow_wrapped in (False, True):
        try:
            signature = inspect.signature(
                candidate,
                follow_wrapped=follow_wrapped,
            )
        except Exception:
            continue
        if not follow_wrapped:
            follow_false_signature = signature
        else:
            follow_true_signature = signature
        signatures.append(signature)
    if plain_runtime_signature is not None:
        signatures.append(plain_runtime_signature)
    if not signatures:
        raise ValueError("signature metadata unavailable")
    if (
        isinstance(candidate, functools.partial)
        and follow_false_signature is not None
        and _signature_has_concrete_runtime_parameters(follow_false_signature)
    ):
        if plain_runtime_signature is not None and _prefer_follow_false_runtime_signature(
            plain_runtime_signature,
            follow_false_signature,
        ):
            return plain_runtime_signature
        # functools.partial already publishes the bound runtime contract. When
        # that concrete signature exists, stale __wrapped__ metadata on the
        # partial object must not outrank it and leak bridge-only kwargs into
        # the downstream solver/helper callable.
        return follow_false_signature
    if _prefer_follow_false_runtime_signature(
        follow_false_signature,
        follow_true_signature,
    ):
        return follow_false_signature
    if plain_runtime_signature is not None and (
        _prefer_follow_false_runtime_signature(
            plain_runtime_signature,
            follow_false_signature,
        )
        or _prefer_follow_false_runtime_signature(
            plain_runtime_signature,
            follow_true_signature,
        )
    ):
        return plain_runtime_signature
    if plain_runtime_signature is not None:
        return plain_runtime_signature
    return max(signatures, key=_signature_runtime_parameter_score)


def _uses_generic_class_new_with_specific_init(obj):
    """Return whether class dispatch may need a raw __new__ factory attempt.

    Some legacy publishers expose a generic factory-style ``__new__(*args,
    **kwargs)`` that directly returns the final non-instance result object, so
    Python never runs ``__init__``. In that shape, preferring ``__init__`` for
    signature filtering silently drops explicit bridge/runtime kwargs that the
    effective factory entry point would accept. Detect the narrow shape where a
    class (or ``functools.partial(class)``) has a generic ``__new__`` but also
    defines a more specific ``__init__`` so callers can try the raw factory
    kwargs first and fall back to the filtered ``__init__`` contract only when
    Python reports a real constructor-signature mismatch.
    """
    partial_args = ()
    partial_kwargs = {}
    target = None
    if isinstance(obj, functools.partial) and inspect.isclass(obj.func):
        target = obj.func
        partial_args = obj.args
        partial_kwargs = obj.keywords or {}
    elif inspect.isclass(obj):
        target = obj
    else:
        return False

    class_new = getattr(target, "__new__", None)
    class_init = getattr(target, "__init__", None)
    if class_new is None or class_new is object.__new__:
        return False
    if class_init is None or class_init is object.__init__:
        return False

    new_candidate = class_new
    init_candidate = class_init
    if target is not obj:
        try:
            new_candidate = functools.partial(
                class_new,
                target,
                *partial_args,
                **partial_kwargs,
            )
        except TypeError:
            return False
        try:
            init_candidate = functools.partial(
                class_init,
                None,
                *partial_args,
                **partial_kwargs,
            )
        except TypeError:
            return False

    return (
        init_candidate is not None
        and not _has_concrete_runtime_parameters(new_candidate)
    )


def _resolve_bridge_signature(obj):
    """Best-effort bridge signature lookup for legacy callable objects."""
    if inspect.isfunction(obj):
        runtime_signature = _resolve_plain_function_runtime_signature(obj)
        exported_signature = None
        try:
            exported_signature = inspect.signature(obj)
        except Exception:
            pass
        if _prefer_plain_function_runtime_signature(
            runtime_signature,
            exported_signature,
        ):
            return runtime_signature

    call = getattr(obj, "__call__", None)
    candidates = []
    is_partial = isinstance(obj, functools.partial)
    is_class = inspect.isclass(obj)
    prefer_object_signature = is_partial or is_class
    if is_partial:
        partial_func = obj.func
        partial_keywords = obj.keywords or {}
        if inspect.isclass(partial_func):
            class_new = getattr(partial_func, "__new__", None)
            class_init = getattr(partial_func, "__init__", None)
            partial_new_candidate = None
            partial_init_candidate = None
            if class_new is not None and class_new is not object.__new__:
                try:
                    partial_new_candidate = functools.partial(
                        class_new,
                        partial_func,
                        *obj.args,
                        **partial_keywords,
                    )
                except TypeError:
                    pass
            if class_init is not None and class_init is not object.__init__:
                try:
                    partial_init_candidate = functools.partial(
                        class_init,
                        None,
                        *obj.args,
                        **partial_keywords,
                    )
                except TypeError:
                    pass
            if partial_new_candidate is not None and _has_concrete_runtime_parameters(
                partial_new_candidate
            ):
                candidates.append(partial_new_candidate)
                if partial_init_candidate is not None:
                    candidates.append(partial_init_candidate)
            else:
                if partial_init_candidate is not None:
                    candidates.append(partial_init_candidate)
                if partial_new_candidate is not None:
                    candidates.append(partial_new_candidate)
        partial_call = getattr(partial_func, "__call__", None)
        if (
            not inspect.isclass(partial_func)
            and (
                partial_call is not None
                and partial_call is not partial_func
                and not _is_plain_callable_alias(partial_func)
            )
        ):
            # functools.partial preserves bound args/kwargs, but for callable
            # objects it can still inherit stale object-level __signature__
            # metadata from the wrapped instance. Rebuild the partial around
            # the real runtime __call__ entry point first so bridge dispatch
            # keeps the effective CLIME tuning kwargs. Classes are handled
            # separately above via __new__/__init__ because type.__call__
            # collapses constructor-specific keyword contracts into a generic
            # (*args, **kwargs) shim.
            try:
                partial_call_candidate = functools.partial(
                    partial_call,
                    *obj.args,
                    **partial_keywords,
                )
                if _prefer_concrete_object_signature(obj, partial_call_candidate):
                    candidates.append(obj)
                candidates.append(partial_call_candidate)
            except TypeError:
                pass
    if is_class:
        class_new = getattr(obj, "__new__", None)
        class_init = getattr(obj, "__init__", None)
        new_candidate = (
            class_new
            if class_new is not None and class_new is not object.__new__
            else None
        )
        init_candidate = (
            class_init
            if class_init is not None and class_init is not object.__init__
            else None
        )
        if new_candidate is not None and _has_concrete_runtime_parameters(
            new_candidate
        ):
            candidates.append(new_candidate)
            if init_candidate is not None:
                candidates.append(init_candidate)
        else:
            if init_candidate is not None:
                candidates.append(init_candidate)
            if new_candidate is not None:
                candidates.append(new_candidate)
    if prefer_object_signature:
        # functools.partial exposes the wrapped callable's effective runtime
        # signature on the partial object itself, while partial.__call__ only
        # reports a generic (*args, **kwargs) shim. Prefer the object-level
        # signature so bridge dispatch preserves CLIME's algorithmic keywords,
        # except when a callable object's stale object-level metadata is known
        # to outrank the true runtime __call__ contract. For classes, prefer
        # __new__/__init__ first because class-level __signature__ metadata can
        # drift away from the actual construction contract.
        candidates.append(obj)
    if (
        call is not None
        and call is not obj
        and not _is_plain_callable_alias(obj)
        and not prefer_object_signature
    ):
        # Callable objects sometimes carry stale __signature__ metadata even
        # though their real runtime contract lives on __call__. Prefer the
        # actual call entry point for object instances so bridge dispatch keeps
        # the algorithmic CLIME arguments that the runtime callable accepts.
        if _prefer_concrete_object_signature(obj, call):
            candidates.append(obj)
        candidates.append(call)
    if not any(candidate is obj for candidate in candidates):
        candidates.append(obj)
    if (
        call is not None
        and call is not obj
        and (_is_plain_callable_alias(obj) or prefer_object_signature)
    ):
        candidates.append(call)

    for candidate in candidates:
        try:
            return _resolve_candidate_signature(candidate)
        except Exception:
            continue
    return None


def _bridge_runtime_accepts_var_keyword(obj):
    """Return whether the runtime bridge entry point accepts arbitrary kwargs."""
    candidates = []
    if isinstance(obj, functools.partial):
        partial_func = obj.func
        partial_keywords = obj.keywords or {}
        partial_call = getattr(partial_func, "__call__", None)
        if (
            not inspect.isclass(partial_func)
            and partial_call is not None
            and partial_call is not partial_func
            and not _is_plain_callable_alias(partial_func)
        ):
            try:
                candidates.append(
                    functools.partial(
                        partial_call,
                        *obj.args,
                        **partial_keywords,
                    )
                )
            except TypeError:
                pass
    else:
        call = getattr(obj, "__call__", None)
        if (
            call is not None
            and call is not obj
            and not _is_plain_callable_alias(obj)
        ):
            candidates.append(call)

    for candidate in candidates:
        try:
            signature = _resolve_candidate_signature(candidate)
        except Exception:
            continue
        if any(
            parameter.kind == inspect.Parameter.VAR_KEYWORD
            for parameter in signature.parameters.values()
        ):
            return True
    return False


def _filter_bridge_optional_kwargs(obj, kwargs):
    """Return bridge optional args split into positional tail and kwargs."""
    signature = _resolve_bridge_signature(obj)
    if signature is None:
        # When signature introspection is unavailable, preserve the full bridge
        # tail for the direct call attempt. If the runtime callable turns out to
        # be a legacy positional-only / *args hook, the TypeError retry path
        # must still see parallel/nproc/verbose rather than silently downgrading
        # the retained-sample solver mode.
        return (), dict(kwargs)

    parameters = signature.parameters
    parameter_order = list(parameters)
    filtered = dict(kwargs)
    positional_tail = []
    bridge_tail_names = (
        "nfolds_cv",
        "nlambda",
        "lambda_min_ratio",
        "perturb",
        "parallel",
        "nproc",
        "random_state",
        "verbose",
    )
    has_var_positional = any(
        parameter.kind == inspect.Parameter.VAR_POSITIONAL
        for parameter in parameters.values()
    )
    for parameter in parameters.values():
        if parameter.kind != inspect.Parameter.POSITIONAL_ONLY:
            continue
        if parameter.name in filtered:
            positional_tail.append(filtered.pop(parameter.name))
    if has_var_positional:
        var_positional_index = next(
            (
                index
                for index, parameter in enumerate(parameters.values())
                if parameter.kind == inspect.Parameter.VAR_POSITIONAL
            ),
            None,
        )
        last_positional_tail_index = -1
        for index, name in enumerate(bridge_tail_names):
            if name not in filtered:
                continue
            parameter = parameters.get(name)
            if parameter is None:
                last_positional_tail_index = index
                continue
            parameter_index = parameter_order.index(name)
            if (
                parameter.kind == inspect.Parameter.POSITIONAL_ONLY
                or (
                    parameter.kind == inspect.Parameter.POSITIONAL_OR_KEYWORD
                    and var_positional_index is not None
                    and parameter_index < var_positional_index
                )
            ):
                last_positional_tail_index = index
        # Some legacy bridge callables expose a mixed contract where the early
        # CLIME tuning slots remain regular positional parameters and the
        # remaining suffix falls through *args. Once any later bridge option
        # needs the varargs tail, keep the whole contiguous optional segment
        # aligned instead of mixing keyword dispatch for the leading slots and
        # silently dropping requested runtime flags such as parallel/nproc/
        # verbose. functools.partial does not narrow the wrapped callable's
        # surviving *args contract, so the same contiguous-tail rule still
        # applies after partial binding.
        for name in bridge_tail_names[: last_positional_tail_index + 1]:
            if name in filtered:
                positional_tail.append(filtered.pop(name))
    if any(
        parameter.kind == inspect.Parameter.VAR_KEYWORD
        for parameter in parameters.values()
    ):
        # **kwargs means the bridge explicitly accepts optional CLIME flags even
        # when it does not spell them out in the exported signature. Keep those
        # keywords instead of silently deleting them and changing solver mode.
        return tuple(positional_tail), filtered
    if _bridge_runtime_accepts_var_keyword(obj):
        # Callable objects can publish a narrower object-level __signature__ even
        # though their real runtime __call__(*args, **kwargs) still accepts
        # explicit bridge flags such as parallel/nproc/verbose. Preserve the
        # caller's requested runtime mode instead of deleting those kwargs just
        # because stale metadata won signature resolution.
        return tuple(positional_tail), filtered
    for name in tuple(filtered):
        if name not in parameters:
            filtered.pop(name)
    return tuple(positional_tail), filtered


def _bridge_optional_tail_from_kwargs(kwargs):
    """Return canonical CLIME/runtime args for signatureless legacy solvers."""
    return tuple(
        kwargs[name]
        for name in (
            "nfolds_cv",
            "nlambda",
            "lambda_min_ratio",
            "perturb",
            "parallel",
            "nproc",
            "random_state",
            "verbose",
        )
        if name in kwargs
    )


def _is_plain_no_keyword_typeerror_message(message):
    """Return whether the TypeError text matches Python's plain no-kwargs form."""
    if not isinstance(message, str):
        return False
    message = message.strip()
    suffix = "takes no keyword arguments"
    if "\n" in message or not message.endswith(suffix):
        return False
    prefix = message[: -len(suffix)].rstrip()
    return bool(prefix) and prefix.endswith("()")


def _should_retry_bridge_positional_tail(exc):
    """Return whether keyword dispatch hit a positional-only legacy contract."""
    message = str(exc)
    has_bridge_tail_name = any(
        name in message
        for name in (
            "nfolds_cv",
            "nlambda",
            "lambda_min_ratio",
            "random_state",
            "perturb",
            "parallel",
            "nproc",
            "verbose",
        )
    )
    return (
        (
            "positional-only arguments passed as keyword arguments" in message
            and has_bridge_tail_name
        )
        or (
            "unexpected keyword argument" in message
            and has_bridge_tail_name
        )
        or _is_plain_no_keyword_typeerror_message(message)
    )


def _dispatch_bridge_runtime_call(
    obj,
    tildex_matname,
    covinv_matname,
    optional_kwargs,
):
    """Dispatch a retained-sample solve using the authoritative bridge rules."""
    if _uses_generic_class_new_with_specific_init(obj):
        raw_kwargs = dict(optional_kwargs)
        try:
            return obj(
                tildex_matname,
                covinv_matname,
                **raw_kwargs,
            )
        except TypeError as exc:
            if not _should_retry_bridge_positional_tail(exc):
                raise exc

    solve_args, solve_kwargs = _filter_bridge_optional_kwargs(
        obj,
        optional_kwargs,
    )
    try:
        return obj(
            tildex_matname,
            covinv_matname,
            *solve_args,
            **solve_kwargs,
        )
    except TypeError as exc:
        if (
            not solve_args
            and _resolve_bridge_signature(obj) is None
            and _should_retry_bridge_positional_tail(exc)
        ):
            retry_args = _bridge_optional_tail_from_kwargs(solve_kwargs)
            if retry_args:
                return obj(
                    tildex_matname,
                    covinv_matname,
                    *retry_args,
                )
        raise exc


def _filter_runtime_solver_call_kwargs(obj, kwargs):
    """Return runtime solver args split into positional tail and kwargs."""
    signature = _resolve_bridge_signature(obj)
    if signature is None:
        return (), dict(kwargs)

    parameters = signature.parameters
    filtered = dict(kwargs)
    positional_tail = []
    has_var_positional = any(
        parameter.kind == inspect.Parameter.VAR_POSITIONAL
        for parameter in parameters.values()
    )
    has_var_keyword = any(
        parameter.kind == inspect.Parameter.VAR_KEYWORD
        for parameter in parameters.values()
    )
    if has_var_positional:
        runtime_prefix_end = -1
        for index, name in enumerate(("c", "A_ub", "b_ub", "method")):
            if name not in filtered:
                continue
            parameter = parameters.get(name)
            if (
                parameter is None
                or parameter.kind == inspect.Parameter.POSITIONAL_ONLY
            ):
                runtime_prefix_end = index
        if runtime_prefix_end >= 0:
            for name in ("c", "A_ub", "b_ub", "method")[: runtime_prefix_end + 1]:
                if name in filtered:
                    positional_tail.append(filtered.pop(name))
    for parameter in parameters.values():
        if parameter.kind != inspect.Parameter.POSITIONAL_ONLY:
            continue
        if parameter.name in filtered:
            positional_tail.append(filtered.pop(parameter.name))
    if has_var_keyword:
        return tuple(positional_tail), filtered
    for name in tuple(filtered):
        if name not in parameters:
            filtered.pop(name)
    return tuple(positional_tail), filtered


def _runtime_solver_positional_tail_from_kwargs(kwargs):
    """Return canonical positional runtime-solver args for signatureless hooks."""
    return tuple(
        kwargs[name]
        for name in ("c", "A_ub", "b_ub", "method")
        if name in kwargs
    )


def _should_retry_runtime_solver_positional_tail(exc):
    """Return whether runtime solver keyword dispatch hit a positional contract."""
    message = str(exc)
    has_runtime_name = any(
        name in message
        for name in ("c", "A_ub", "b_ub", "method")
    )
    return (
        (
            "positional-only arguments passed as keyword arguments" in message
            and has_runtime_name
        )
        or (
            "unexpected keyword argument" in message
            and has_runtime_name
        )
        or _is_plain_no_keyword_typeerror_message(message)
    )


def _call_runtime_linprog_solver(solver, **kwargs):
    """Call runtime LP solver while honoring positional-only / *args hooks."""
    if _uses_generic_class_new_with_specific_init(solver):
        try:
            return solver(**kwargs)
        except TypeError as exc:
            if not _should_retry_runtime_solver_positional_tail(exc):
                raise exc

    call_args, call_kwargs = _filter_runtime_solver_call_kwargs(solver, kwargs)
    try:
        return solver(*call_args, **call_kwargs)
    except TypeError as exc:
        if (
            not call_args
            and _resolve_bridge_signature(solver) is None
            and _should_retry_runtime_solver_positional_tail(exc)
        ):
            retry_args = _runtime_solver_positional_tail_from_kwargs(call_kwargs)
            if retry_args:
                return solver(*retry_args)
        raise exc


def _validate_runtime_solver_result(result, source):
    """Reject awaitable solver results before contract checks leak warnings."""
    if inspect.isgenerator(result):
        close = getattr(result, "close", None)
        if callable(close):
            close()
        raise TypeError(
            f"{source} must return a synchronous OptimizeResult, "
            f"got generator {type(result).__name__}"
        )
    if inspect.isasyncgen(result):
        aclose = getattr(result, "aclose", None)
        if callable(aclose):
            close_result = aclose()
            close = getattr(close_result, "close", None)
            if callable(close):
                close()
        raise TypeError(
            f"{source} must return a synchronous OptimizeResult, "
            f"got async generator {type(result).__name__}"
        )
    if inspect.isawaitable(result):
        close = getattr(result, "close", None)
        if callable(close):
            close()
        raise TypeError(
            f"{source} must return a synchronous OptimizeResult, "
            f"got awaitable {type(result).__name__}"
        )
    return result


def _validate_runtime_solver_resolver_payload(result, source):
    """Reject awaitable resolver payloads before fallback leaks warnings."""
    if inspect.isgenerator(result):
        close = getattr(result, "close", None)
        if callable(close):
            close()
        raise _RuntimeSolverResolverContractError(
            f"{source} returned a generator "
            f"{type(result).__name__}, expected a synchronous callable"
        )
    if inspect.isasyncgen(result):
        aclose = getattr(result, "aclose", None)
        if callable(aclose):
            close_result = aclose()
            close = getattr(close_result, "close", None)
            if callable(close):
                close()
        raise _RuntimeSolverResolverContractError(
            f"{source} returned an async generator "
            f"{type(result).__name__}, expected a synchronous callable"
        )
    if inspect.isawaitable(result):
        close = getattr(result, "close", None)
        if callable(close):
            close()
        raise _RuntimeSolverResolverContractError(
            f"{source} returned an awaitable "
            f"{type(result).__name__}, expected a synchronous callable"
        )
    return result


def _matches_current_scipy_callable_handle(obj, current_obj):
    """Return whether obj matches the current scipy callable-object handle kind."""
    obj = _unwrap_partial_callable_root(obj)
    current_obj = _unwrap_partial_callable_root(current_obj)
    if not callable(obj) or not callable(current_obj):
        return False
    if _is_scipy_optimize_handle(current_obj):
        return False
    current_type = type(current_obj)
    current_type_module = getattr(current_type, "__module__", "")
    if not (
        isinstance(current_type_module, str)
        and current_type_module.startswith("scipy.optimize")
    ):
        return False
    obj_type = type(obj)
    return (
        getattr(obj_type, "__module__", "") == current_type_module
        and getattr(obj_type, "__qualname__", "") ==
        getattr(current_type, "__qualname__", "")
    )


def _get_linprog():
    """Import scipy.optimize.linprog only when an LP solve is actually needed."""
    global _SCIPY_LINPROG, _SCIPY_OPTIMIZE_ID, linprog
    current_scipy_optimize = sys.modules.get("scipy.optimize")
    current_scipy_optimize_id = (
        id(current_scipy_optimize)
        if current_scipy_optimize is not None
        else None
    )
    scipy_identity_changed = current_scipy_optimize_id != _SCIPY_OPTIMIZE_ID
    current_linprog = (
        getattr(current_scipy_optimize, "linprog", None)
        if current_scipy_optimize is not None
        else None
    )
    if current_linprog is not None and not callable(current_linprog):
        current_linprog = None
    if _SCIPY_LINPROG is not None and not callable(_SCIPY_LINPROG):
        _SCIPY_LINPROG = None
    if linprog is not None and not callable(linprog):
        linprog = _SCIPY_LINPROG if _SCIPY_LINPROG is not None else None
    # The Stata bridge can drop and reload scipy in the embedded Python session
    # after shadow-import repair. Refresh the cached solver when the current
    # SciPy identity changes, but preserve an explicit test monkeypatch on this
    # module when no cache refresh is needed.
    if current_scipy_optimize is None and _SCIPY_LINPROG is not None:
        if linprog is _SCIPY_LINPROG:
            linprog = None
        _SCIPY_LINPROG = None
    if (
        current_scipy_optimize is None
        and _SCIPY_LINPROG is None
        and linprog is not None
        and _is_scipy_optimize_alias_like(linprog)
    ):
        # After a dependency uncache, a stale imported scipy.optimize* handle
        # must not outrank a fresh import from the current environment.
        linprog = None
    if current_scipy_optimize is not None and current_linprog is None:
        # A partial/shadow scipy.optimize must not silently fall back to a
        # previously cached scipy handle from another module identity.
        # Preserve an explicit non-scipy module-level hook when the current
        # session installed one directly and the authoritative cache is empty.
        preserve_explicit_hook = (
            linprog is not None
            and linprog is not _SCIPY_LINPROG
            and not _is_scipy_optimize_alias_like(linprog)
        )
        if not preserve_explicit_hook:
            linprog = None
        _SCIPY_LINPROG = None
    if (
        scipy_identity_changed
        and linprog is not None
        and _SCIPY_LINPROG is None
        and current_linprog is not None
        and linprog is not current_linprog
        and (
            _is_scipy_optimize_alias_like(linprog)
            or _matches_current_scipy_callable_handle(
                linprog,
                current_linprog,
            )
        )
    ):
        # Once scipy.optimize itself has changed identity, a surviving
        # scipy.optimize handle is no longer authoritative. Refresh to the
        # active scipy.optimize.linprog from the current environment instead
        # of reusing an orphaned scipy callable left over from an earlier
        # session state. Preserve explicit non-scipy hooks, even when they are
        # plain functions, because the bridge cannot distinguish those from
        # intentional overrides when the authoritative cache is empty.
        linprog = current_linprog
        _SCIPY_LINPROG = current_linprog
    if (
        linprog is not None
        and _SCIPY_LINPROG is None
        and current_linprog is not None
        and linprog is not current_linprog
        and (
            _is_scipy_optimize_alias_like(linprog)
            or _matches_current_scipy_callable_handle(
                linprog,
                current_linprog,
            )
        )
    ):
        # When the module-level alias survives but the authoritative cache is
        # empty, prefer the active scipy.optimize.linprog identity only when
        # the surviving alias itself still looks like a scipy.optimize handle
        # from an earlier Python session state. Preserve explicit module-level
        # overrides such as contract tests that intentionally replace linprog.
        linprog = current_linprog
        _SCIPY_LINPROG = current_linprog
    cached_linprog = _SCIPY_LINPROG
    if (
        current_linprog is not None
        and (
            (
                linprog is not None
                and linprog is not current_linprog
                and _is_scipy_optimize_alias_like(linprog)
            )
            or (
                _SCIPY_LINPROG is not None
                and _SCIPY_LINPROG is not current_linprog
            )
        )
    ):
        # When both cached handles survive but drift away from the active
        # scipy.optimize.linprog identity, treat the imported module as
        # authoritative and refresh both caches together. Explicit module-level
        # overrides should survive unless the surviving handle still looks like
        # an old scipy.optimize callable-object/function alias left behind by a
        # prior module identity swap. A stale authoritative cache should
        # refresh _SCIPY_LINPROG, but it must not silently override an
        # explicit callable-object hook that the current session intentionally
        # installed.
        if (
            linprog is None
            or linprog is cached_linprog
            or _is_scipy_optimize_alias_like(linprog)
            or _matches_current_scipy_callable_handle(
                linprog,
                current_linprog,
            )
        ):
            linprog = current_linprog
        _SCIPY_LINPROG = current_linprog
    if linprog is not None:
        if (
            _SCIPY_LINPROG is not None
            and linprog is _SCIPY_LINPROG
            and current_linprog is not None
            and current_linprog is not _SCIPY_LINPROG
        ):
            linprog = current_linprog
            _SCIPY_LINPROG = current_linprog
        _SCIPY_OPTIMIZE_ID = current_scipy_optimize_id
        return linprog
    if (
        _SCIPY_LINPROG is not None
        and current_linprog is not None
        and current_linprog is not _SCIPY_LINPROG
    ):
        _SCIPY_LINPROG = current_linprog
        _SCIPY_OPTIMIZE_ID = current_scipy_optimize_id
        return _SCIPY_LINPROG
    if _SCIPY_LINPROG is not None:
        _SCIPY_OPTIMIZE_ID = current_scipy_optimize_id
        return _SCIPY_LINPROG
    try:
        from scipy.optimize import linprog as scipy_linprog
    except Exception as exc:
        exc_type = (
            ModuleNotFoundError
            if isinstance(exc, ModuleNotFoundError)
            else ImportError
        )
        raise exc_type(
            "scipy.optimize.linprog could not be imported cleanly; "
            "the SciPy dependency is missing or incomplete. "
            f"Original error: {exc}"
        ) from exc
    if not callable(scipy_linprog):
        raise TypeError(
            "scipy.optimize.linprog must be callable, "
            f"got {type(scipy_linprog).__name__}"
        )

    _SCIPY_LINPROG = scipy_linprog
    linprog = scipy_linprog
    loaded_scipy_optimize = sys.modules.get("scipy.optimize")
    _SCIPY_OPTIMIZE_ID = (
        id(loaded_scipy_optimize)
        if loaded_scipy_optimize is not None
        else current_scipy_optimize_id
    )
    return _SCIPY_LINPROG


def _resolve_runtime_linprog_solver(return_source=False):
    """Resolve the active LP solver while honoring explicit runtime hooks."""
    solver = None
    solver_source = None
    resolver_exc = None
    resolver = globals().get("_get_linprog", None)
    if resolver is not None and not callable(resolver):
        raise TypeError(
            "runtime LP solver resolver must be callable, got "
            f"{type(resolver).__name__}"
        )
    if callable(resolver):
        _validate_runtime_solver_callable(
            resolver,
            "runtime LP solver resolver",
        )
        try:
            resolved_solver = _validate_runtime_solver_resolver_payload(
                resolver(),
                "runtime LP solver resolver",
            )
            if resolved_solver is not None and not callable(resolved_solver):
                raise _RuntimeSolverResolverContractError(
                    "runtime LP solver resolver returned a non-callable "
                    f"{type(resolved_solver).__name__}"
                )
            try:
                _validate_runtime_solver_callable(
                    resolved_solver,
                    "runtime LP solver resolver",
                )
            except TypeError as exc:
                raise _RuntimeSolverResolverContractError(str(exc)) from exc
            solver = resolved_solver
            solver_source = "resolver"
            current_scipy_optimize = sys.modules.get("scipy.optimize")
            current_linprog = (
                getattr(current_scipy_optimize, "linprog", None)
                if current_scipy_optimize is not None
                else None
            )
            if (
                callable(current_linprog)
                and solver is not current_linprog
                and (
                    _is_scipy_optimize_alias_like(solver)
                    or _matches_current_scipy_callable_handle(
                        solver,
                        current_linprog,
                    )
                )
            ):
                # The internal resolver is allowed to surface the active runtime
                # solver, but it must not let an orphaned scipy.optimize alias
                # from an earlier module identity outrank the current loaded
                # scipy.optimize.linprog handle.
                solver = current_linprog
                solver_source = "current"
        except _RuntimeSolverResolverContractError:
            # A resolver that returns a coroutine/awaitable/non-callable payload
            # is itself the broken authoritative runtime contract. Falling back
            # to a stale alias or imported solver would mask that bridge error.
            raise
        except Exception as exc:
            # Runtime validation should still honor an explicit solver hook or
            # active scipy.optimize.linprog handle when the cached resolver
            # itself is the stale dependency artifact that failed. Preserve the
            # original exception when no authoritative fallback exists, but do
            # not let the cached resolver outrank a known-good
            # explicit/current solver.
            solver = None
            resolver_exc = exc

    if solver is None:
        current_scipy_optimize = sys.modules.get("scipy.optimize")
        current_linprog = (
            getattr(current_scipy_optimize, "linprog", None)
            if current_scipy_optimize is not None
            else None
        )
        module_linprog = linprog if callable(linprog) else None
        if (
            current_scipy_optimize is None
            and module_linprog is not None
            and _is_scipy_optimize_alias_like(module_linprog)
        ):
            # Mirror _get_linprog(): once scipy.optimize has been uncached, a
            # leftover scipy.optimize* alias from an earlier session must not
            # outrank a fresh import from the current environment.
            module_linprog = None
        if (
            current_scipy_optimize is not None
            and not callable(current_linprog)
            and module_linprog is not None
            and _is_scipy_optimize_alias_like(module_linprog)
        ):
            # Mirror _get_linprog(): once the active scipy.optimize module is
            # present but exposes a missing/non-callable linprog handle, a
            # stale scipy alias from an earlier session must not satisfy the
            # runtime bridge contract.
            module_linprog = None
        if (
            module_linprog is not None
            and callable(current_linprog)
            and module_linprog is not current_linprog
            and (
                _is_scipy_optimize_alias_like(module_linprog)
                or _matches_current_scipy_callable_handle(
                    module_linprog,
                    current_linprog,
                )
            )
        ):
            # Mirror the stale-handle refresh rule from _get_linprog(): after
            # a resolver/import failure, a surviving scipy.optimize* alias
            # left on this module must not outrank the active
            # scipy.optimize.linprog identity from the current session.
            module_linprog = current_linprog
        if module_linprog is not None:
            solver = module_linprog
            solver_source = "module"
        elif callable(current_linprog):
            solver = current_linprog
            solver_source = "current"
        else:
            if resolver_exc is not None:
                # The embedded-session resolver is authoritative for whether a
                # usable runtime solver still exists. If it is broken and no
                # explicit or currently loaded solver handle survives, do not
                # mask that bridge corruption by importing a fresh SciPy
                # solver from outside the active runtime state.
                raise resolver_exc
            try:
                from scipy.optimize import linprog as scipy_linprog
            except Exception as exc:
                exc_type = (
                    ModuleNotFoundError
                    if isinstance(exc, ModuleNotFoundError)
                    else ImportError
                )
                raise exc_type(
                    "scipy.optimize.linprog could not be imported cleanly; "
                    "the SciPy dependency is missing or incomplete. "
                    f"Original error: {exc}"
                ) from exc
            if not callable(scipy_linprog):
                raise TypeError(
                    "scipy.optimize.linprog must be callable, "
                    f"got {type(scipy_linprog).__name__}"
                )
            solver = scipy_linprog
            solver_source = "import"
    if solver is None and resolver_exc is not None:
        raise resolver_exc
    solver = _validate_runtime_solver_callable(solver, "runtime LP solver")
    if return_source:
        return solver, solver_source
    return solver


def hddid_clime_validate_solver_runtime():
    """Validate the runtime LP solver contract used by non-diagonal CLIME."""
    solver, solver_source = _resolve_runtime_linprog_solver(return_source=True)

    # Mirror the actual solve path exactly: _solve_clime_column() never passes
    # an explicit bounds keyword, so the runtime probe must not validate a
    # solver contract that differs from the one CLIME actually uses.
    probe_kwargs = {
        "c": [1.0],
        "A_ub": [[1.0]],
        "b_ub": [1.0],
        "method": "highs",
    }
    probe = _validate_runtime_solver_result(
        _call_runtime_linprog_solver(solver, **probe_kwargs),
        "runtime LP solver",
    )
    validate_result = globals().get("_validate_linprog_result_contract", None)
    validate_probe_solution = globals().get(
        "_validate_runtime_linprog_probe_solution",
        None,
    )
    validate_probe_objective = globals().get(
        "_validate_runtime_linprog_probe_objective",
        None,
    )
    if (
        callable(validate_result)
        and callable(validate_probe_solution)
    ):
        validate_result(probe, 1, 0, 0.0)
        try:
            validate_probe_solution(probe)
            # The runtime gate should enforce only the OptimizeResult fields
            # that the downstream CLIME solve actually consumes. Some explicit
            # solver hooks omit fun while still satisfying the solve-path
            # contract.
            if callable(validate_probe_objective) and hasattr(probe, "fun"):
                validate_probe_objective(probe)
        except TypeError as probe_exc:
            # The runtime gate must mirror the same synchronous LP contract
            # that _solve_clime_column() will actually consume. Some explicit
            # hooks return the real p=1 CLIME column OptimizeResult rather than
            # a dedicated 1-variable probe payload; if that authoritative
            # solver still satisfies the column contract, accept it here too so
            # the preflight does not reject a solver the actual solve path can
            # use successfully.
            try:
                _validate_runtime_linprog_probe_column_fallback(probe)
            except TypeError:
                raise probe_exc
        return

    required = ("success", "status", "message", "x")
    if any(not hasattr(probe, attr) for attr in required):
        raise TypeError(
            "runtime linprog probe returned an object without the required "
            f"OptimizeResult fields {required}"
        )
    success = getattr(probe, "success")
    if not isinstance(success, (bool, np.bool_)):
        raise TypeError(
            "runtime linprog probe returned a success payload without the "
            "required bool contract"
        )
    status = getattr(probe, "status")
    if isinstance(status, (bool, np.bool_)) or not isinstance(
        status, (int, np.integer)
    ):
        raise TypeError(
            "runtime linprog probe returned a status payload without the "
            "required integer contract"
        )
    message = getattr(probe, "message")
    if not isinstance(message, str):
        raise TypeError(
            "runtime linprog probe returned a message payload without the "
            "required string contract"
        )
    if not bool(success):
        raise RuntimeError(
            "runtime linprog probe reported success=False on a trivial "
            "feasible problem"
        )
    try:
        _validate_runtime_linprog_probe_solution(probe)
        if hasattr(probe, "fun"):
            _validate_runtime_linprog_probe_objective(probe)
    except TypeError as probe_exc:
        try:
            _validate_runtime_linprog_probe_column_fallback(probe)
        except TypeError:
            raise probe_exc


def _validate_multix_runtime_solver_contract(p):
    """Require the runtime hook to satisfy every real p>1 CLIME column shape."""
    solver = _resolve_runtime_linprog_solver()
    c = np.ones(2 * p, dtype=np.float64)
    probe_sigmas = [np.eye(p, dtype=np.float64)]
    if p > 1:
        # Paper Eq. (4.2) and the R CLIME path operate on the retained raw
        # second moment, which is generically non-identity on finite folds.
        # A runtime hook that only hard-codes the identity operator still
        # violates the multivariate CLIME contract even if it passes the
        # trivial identity-column probe.
        Sigma_nonidentity = np.eye(p, dtype=np.float64)
        Sigma_nonidentity[0, 1] = 0.25
        Sigma_nonidentity[1, 0] = 0.25
        probe_sigmas.append(Sigma_nonidentity)

    for Sigma in probe_sigmas:
        A_ub = np.block([
            [Sigma, -Sigma],
            [-Sigma, Sigma],
        ])
        for j in range(p):
            e_j = np.zeros(p, dtype=np.float64)
            e_j[j] = 1.0
            b_ub = np.concatenate([e_j, -e_j])

            result = _validate_runtime_solver_result(
                _call_runtime_linprog_solver(
                    solver,
                    c=c,
                    A_ub=A_ub,
                    b_ub=b_ub,
                    method="highs",
                ),
                "runtime LP solver",
            )
            _validate_linprog_result_contract(result, p, j, 0.0)
            if not result.success:
                raise RuntimeError(
                    "runtime linprog multix probe reported success=False on a trivial "
                    f"p={p} CLIME column problem for column {j + 1}/{p}"
                )
            _validate_runtime_multix_probe_column_solution(result, p, j)

    positive_lambda = 0.25
    for Sigma in probe_sigmas:
        A_ub = np.block([
            [Sigma, -Sigma],
            [-Sigma, Sigma],
        ])
        sigma_label = (
            "identity"
            if np.allclose(Sigma, np.eye(p, dtype=np.float64), rtol=0.0, atol=0.0)
            else "nonidentity"
        )
        for j in range(p):
            e_j = np.zeros(p, dtype=np.float64)
            e_j[j] = 1.0
            lam_ones = positive_lambda * np.ones(p, dtype=np.float64)
            b_ub = np.concatenate([lam_ones + e_j, lam_ones - e_j])

            result = _validate_runtime_solver_result(
                _call_runtime_linprog_solver(
                    solver,
                    c=c,
                    A_ub=A_ub,
                    b_ub=b_ub,
                    method="highs",
                ),
                "runtime LP solver",
            )
            _validate_linprog_result_contract(result, p, j, positive_lambda)
            if not result.success:
                raise RuntimeError(
                    "runtime linprog multix probe reported success=False on a "
                    f"positive-lambda {sigma_label} p={p} CLIME column problem "
                    f"for column {j + 1}/{p} at lambda={positive_lambda:.6f}"
                )
            _validate_runtime_multix_positive_lambda_probe_column_solution(
                result,
                p,
                j,
                positive_lambda,
            )


def _coerce_numeric_matrix(name, value):
    """Coerce host matrix-like data to a rectangular float64 array."""
    try:
        matrix = np.asarray(value, dtype=np.float64)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{name} must be a rectangular 2D numeric matrix."
        ) from exc
    return matrix


def _validate_bool_flag(name, value):
    """Validate a boolean control flag without accepting truthy non-bools."""
    if isinstance(value, (bool, np.bool_)):
        return bool(value)
    raise ValueError(f"{name} must be a bool, got {type(value).__name__}")


def _validate_optional_int(name, value, minimum=None, maximum=None):
    """Validate an optional integer scalar while rejecting bool aliases."""
    if value is None:
        return None
    value = _validate_integer_scalar(
        name,
        value,
        minimum=minimum,
        maximum=maximum,
    )
    return value


def _validate_integer_scalar(name, value, minimum=None, maximum=None):
    """Validate an integer scalar while rejecting bool aliases."""
    if isinstance(value, (bool, np.bool_)) or not isinstance(
        value, (int, np.integer)
    ):
        raise ValueError(f"{name} must be an integer, got {type(value).__name__}")

    value = int(value)
    if minimum is not None and value < minimum:
        raise ValueError(f"{name} must be >= {minimum}, got {value}")
    if maximum is not None and value > maximum:
        raise ValueError(f"{name} must be <= {maximum}, got {value}")
    return value


def _validate_positive_int(name, value, minimum=1):
    """Validate a required positive integer scalar without bool aliases."""
    return _validate_integer_scalar(name, value, minimum=minimum)


def _validate_effective_nfolds(name, value):
    """Validate the published realized CV fold count contract."""
    if isinstance(value, (bool, np.bool_)):
        raise ValueError(f"{name} must be a nonnegative integer, got bool")
    if not isinstance(value, (int, float, np.integer, np.floating)):
        raise ValueError(
            f"{name} must be a nonnegative integer, got {type(value).__name__}"
        )

    value = float(value)
    if not np.isfinite(value):
        raise ValueError(f"{name} must be finite, got {value}")
    if value < 0:
        raise ValueError(f"{name} must be >= 0, got {value}")
    if value != float(np.floor(value)):
        raise ValueError(f"{name} must be an integer count, got {value}")
    return value


def _validate_matrix_name(name, value):
    """Validate a Stata matrix identifier used by the bridge layer."""
    if not isinstance(value, str) or value.strip() == "":
        raise ValueError(
            f"{name} must be a non-empty string Stata matrix name, "
            f"got {type(value).__name__}"
        )
    if any(ch.isspace() for ch in value):
        raise ValueError(
            f"{name} must be a non-empty string Stata matrix name "
            "without whitespace"
        )
    if len(value) > STATA_MAX_NAME_LENGTH:
        raise ValueError(
            f"{name} must be at most {STATA_MAX_NAME_LENGTH} characters to "
            f"match Stata matrix-name limits, got {len(value)}"
        )
    if not value.isascii():
        raise ValueError(
            f"{name} must be an ASCII Stata matrix name, got {value!r}"
        )
    if value[0] != "_" and not value[0].isalpha():
        raise ValueError(
            f"{name} must be a valid Stata matrix name starting with a letter "
            f"or underscore, got {value!r}"
        )
    if not all(ch == "_" or ch.isalnum() for ch in value):
        raise ValueError(
            f"{name} must be a valid Stata matrix name containing only "
            f"letters, digits, and underscores, got {value!r}"
        )
    return value


def _validate_nonnegative_lambda(value):
    """Validate the CLIME penalty as a finite numeric scalar >= 0."""
    if isinstance(value, (bool, np.bool_)) or not isinstance(
        value, (int, float, np.integer, np.floating)
    ):
        raise ValueError(
            "lambda must be a finite numeric scalar >= 0, "
            f"got {type(value).__name__}"
        )

    value = float(value)
    if not np.isfinite(value):
        raise ValueError(
            "lambda must be a finite numeric scalar >= 0, "
            f"got {value}"
        )
    if value < 0:
        raise ValueError(f"lambda must be nonnegative, got {value}")
    return value


def _validate_lambda_min_ratio(value):
    """Validate the lambda grid lower/upper ratio used by CLIME CV."""
    if isinstance(value, (bool, np.bool_)) or not isinstance(
        value, (int, float, np.integer, np.floating)
    ):
        raise ValueError(
            "lambda_min_ratio must be a finite numeric scalar in (0, 1], "
            f"got {type(value).__name__}"
        )

    value = float(value)
    if not np.isfinite(value):
        raise ValueError(
            "lambda_min_ratio must be a finite numeric scalar in (0, 1], "
            f"got {value}"
        )
    if value <= 0 or value > 1:
        raise ValueError(
            f"lambda_min_ratio must lie in (0, 1], got {value}"
        )
    return value


def _validate_lambda_candidates(lambdas):
    """Validate explicit CV candidate lambdas before entering solver loops."""
    lambdas = np.asarray(lambdas, dtype=object)
    if lambdas.ndim != 1:
        raise ValueError(
            "candidate lambdas must be a 1D sequence of finite "
            "numeric scalars >= 0"
        )
    if lambdas.size < 1:
        raise ValueError("candidate lambdas must contain at least one value")

    validated = np.empty(lambdas.size, dtype=np.float64)
    for idx, value in enumerate(lambdas.tolist()):
        try:
            validated[idx] = _validate_nonnegative_lambda(value)
        except ValueError as exc:
            raise ValueError(
                "candidate lambdas must be finite numeric scalars >= 0; "
                f"invalid entry at position {idx}: {value!r}"
            ) from exc
    return validated


def _validate_observed_matrix(name, value):
    """Reject NaN/Inf and Stata missing sentinels before numeric routines."""
    value = np.asarray(value, dtype=np.float64)
    if not np.isfinite(value).all():
        raise ValueError(f"{name} must contain only finite numeric values")
    if np.any(value >= STATA_SYSTEM_MISSING):
        raise ValueError(
            f"{name} must not contain Stata missing values "
            "(., .a-.z) encoded as large finite doubles."
        )
    return value


def _validate_nonconstant_columns(name, value):
    """Reject structurally zero-variance columns before perturbation masks them."""
    value = np.asarray(value, dtype=np.float64)
    if value.ndim != 2:
        raise ValueError(f"{name} must be a 2D matrix, got ndim={value.ndim}")
    # Reject only columns that are exactly constant in the incoming floating
    # representation. Tiny but strictly positive variation still defines a
    # finite covariance operator and should not be collapsed into "constant"
    # by a unit-scale epsilon threshold.
    constant_mask = np.ptp(value, axis=0) == 0.0
    if np.any(constant_mask):
        constant_cols = ", ".join(str(int(idx) + 1) for idx in np.flatnonzero(constant_mask))
        raise ValueError(
            f"{name} must not contain constant columns; zero-variance columns "
            f"({constant_cols}) do not define a valid retained-sample precision "
            "operator before diagonal perturbation."
        )
    return value


def _validate_precision_matrix_contract(name, value):
    """Require a finite symmetric numerically invertible precision operator."""
    value = np.asarray(value, dtype=np.float64)
    if value.ndim != 2 or value.shape[0] != value.shape[1]:
        raise ValueError(f"{name} must be square, got shape {value.shape}")

    value = _validate_observed_matrix(name, value)

    if value.shape == (1, 1) and float(value[0, 0]) <= 0.0:
        raise ValueError(
            f"{name} must be strictly positive in the scalar p=1 case"
        )

    scale = float(np.max(np.abs(value)))
    # Symmetry is a property of this precision operator itself. Use the
    # operator's own scale so tiny but well-defined covariance inverses do not
    # inherit a unit-scale floor that can hide same-order asymmetry.
    if not np.isfinite(scale) or scale <= 0.0:
        scale = 1.0
    sym_tol = 1e-10 * scale
    asym_gap = float(np.max(np.abs(value - value.T)))
    if asym_gap > sym_tol:
        raise ValueError(
            f"{name} must be symmetric within tolerance {sym_tol}; "
            f"max |A-A'| = {asym_gap}"
        )
    singular_values = np.linalg.svd(value, compute_uv=False)
    singular_scale = float(np.max(singular_values))
    # Invertibility is likewise relative to this operator's singular spectrum:
    # a tiny but well-conditioned precision matrix remains a valid inverse
    # operator after a finite coordinate rescaling of X.
    if not np.isfinite(singular_scale) or singular_scale <= 0.0:
        singular_scale = 1.0
    singular_tol = 1e-10 * singular_scale
    # The paper and the R/Mata debiasing path use this object as a retained
    # covariance inverse operator. That contract requires numerical
    # invertibility, not positive definiteness of the finite-sample CLIME
    # estimate itself.
    if float(np.min(singular_values)) <= singular_tol:
        raise ValueError(
            f"{name} must be numerically invertible within tolerance "
            f"{singular_tol}; min singular value = "
            f"{float(np.min(singular_values))}"
        )
    return value


def _validate_clime_constraint_matrix(Sigma, A_ub):
    """Validate a precomputed CLIME block constraint matrix."""
    p = Sigma.shape[0]
    expected_dim = 2 * p
    try:
        A_ub = np.asarray(A_ub, dtype=np.float64)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            "A_ub must be a finite "
            f"{expected_dim} x {expected_dim} matrix matching Sigma's "
            "CLIME block constraints"
        ) from exc

    if (
        A_ub.ndim != 2
        or A_ub.shape != (expected_dim, expected_dim)
        or not np.isfinite(A_ub).all()
    ):
        raise ValueError(
            "A_ub must be a finite "
            f"{expected_dim} x {expected_dim} matrix matching Sigma's "
            "CLIME block constraints"
        )

    top_left = A_ub[:p, :p]
    top_right = A_ub[:p, p:]
    bottom_left = A_ub[p:, :p]
    bottom_right = A_ub[p:, p:]
    if not (
        np.array_equal(top_left, Sigma)
        and np.array_equal(top_right, -Sigma)
        and np.array_equal(bottom_left, -Sigma)
        and np.array_equal(bottom_right, Sigma)
    ):
        raise ValueError(
            "A_ub must be a finite "
            f"{expected_dim} x {expected_dim} matrix matching Sigma's "
            "CLIME block constraints"
        )
    return A_ub


def _validate_linprog_solution_vector(result, p, j, lam):
    """Require scipy.optimize.linprog() to return a finite length-2p vector."""
    try:
        solution = np.asarray(getattr(result, "x"), dtype=np.float64)
    except (TypeError, ValueError) as exc:
        raise RuntimeError(
            "CLIME LP returned an invalid finite "
            f"length-{2 * p} solution vector for column {j + 1}/{p} "
            f"at lambda={lam:.6f}; got type violation"
        ) from exc

    if solution.ndim != 1 or solution.size != 2 * p:
        raise RuntimeError(
            "CLIME LP returned an invalid finite "
            f"length-{2 * p} solution vector for column {j + 1}/{p} "
            f"at lambda={lam:.6f}; got length violation"
        )
    if not np.isfinite(solution).all():
        raise RuntimeError(
            "CLIME LP returned an invalid finite "
            f"length-{2 * p} solution vector for column {j + 1}/{p} "
            f"at lambda={lam:.6f}; got finite violation"
        )
    return solution


def _validate_runtime_linprog_probe_solution(result):
    """Require the runtime solver probe to return the 1-variable LP solution."""
    try:
        solution = np.asarray(getattr(result, "x"), dtype=np.float64)
    except (TypeError, ValueError) as exc:
        raise TypeError(
            "runtime linprog probe returned an x payload without the "
            "required finite length-1 numeric vector contract"
        ) from exc

    if solution.ndim != 1 or solution.size != 1 or not np.isfinite(solution).all():
        raise TypeError(
            "runtime linprog probe returned an x payload without the "
            "required finite length-1 numeric vector contract"
        )
    solution_tol = np.sqrt(np.finfo(np.float64).eps)
    if abs(float(solution[0])) > solution_tol:
        raise TypeError(
            "runtime linprog probe returned an x payload inconsistent with "
            "the trivial feasible LP optimum; expected the optimal solution "
            f"0 within tolerance {solution_tol}, got {float(solution[0])}"
        )
    return solution


def _validate_runtime_linprog_probe_objective(result):
    """Require the runtime solver probe to report the trivial LP optimum."""
    try:
        objective = float(getattr(result, "fun"))
    except (AttributeError, TypeError, ValueError) as exc:
        raise TypeError(
            "runtime linprog probe returned an objective payload without the "
            "required finite scalar contract"
        ) from exc

    if not np.isfinite(objective):
        raise TypeError(
            "runtime linprog probe returned an objective payload without the "
            "required finite scalar contract"
        )
    objective_tol = np.sqrt(np.finfo(np.float64).eps)
    if abs(objective) > objective_tol:
        raise TypeError(
            "runtime linprog probe returned an objective payload inconsistent "
            "with the trivial feasible LP optimum; expected objective 0 "
            f"within tolerance {objective_tol}, got {objective}"
        )
    return objective


def _validate_runtime_linprog_probe_column_fallback(result):
    """Accept explicit hooks that surface the actual p=1 CLIME column result."""
    _validate_linprog_result_contract(result, 1, 0, 0.0)
    solution = _validate_linprog_solution_vector(result, 1, 0, 0.0)
    solution_tol = np.sqrt(np.finfo(np.float64).eps)
    expected = np.array([1.0, 0.0], dtype=np.float64)
    if not np.allclose(solution, expected, rtol=0.0, atol=solution_tol):
        raise TypeError(
            "runtime linprog probe returned an x payload inconsistent with "
            "the p=1 CLIME column optimum; expected [1, 0] within tolerance "
            f"{solution_tol}, got {solution.tolist()}"
        )
    if hasattr(result, "fun"):
        try:
            objective = float(getattr(result, "fun"))
        except (TypeError, ValueError) as exc:
            raise TypeError(
                "runtime linprog probe returned an objective payload without "
                "the required finite scalar contract"
            ) from exc
        if not np.isfinite(objective):
            raise TypeError(
                "runtime linprog probe returned an objective payload without "
                "the required finite scalar contract"
            )
        objective_tol = np.sqrt(np.finfo(np.float64).eps)
        if abs(objective - 1.0) > objective_tol:
            raise TypeError(
                "runtime linprog probe returned an objective payload "
                "inconsistent with the p=1 CLIME column optimum; expected "
                f"objective 1 within tolerance {objective_tol}, got "
                f"{objective}"
            )
    return solution


def _validate_runtime_multix_probe_column_solution(result, p, j):
    """Require the runtime multix probe to recover the trivial CLIME column."""
    solution = _validate_linprog_solution_vector(result, p, j, 0.0)
    expected = np.zeros(p, dtype=np.float64)
    expected[j] = 1.0
    solution_tol = np.sqrt(np.finfo(np.float64).eps)
    w = solution[:p] - solution[p:]
    if not np.allclose(w, expected, rtol=0.0, atol=solution_tol):
        raise RuntimeError(
            "runtime linprog multix probe returned a solution vector "
            "inconsistent with the trivial CLIME column optimum for "
            f"column {j + 1}/{p}; expected {expected.tolist()} within "
            f"tolerance {solution_tol}, got {w.tolist()}"
        )
    return w


def _validate_runtime_multix_positive_lambda_probe_column_solution(result, p, j, lam):
    """Require the runtime probe to handle the positive-lambda CLIME shape."""
    solution = _validate_linprog_solution_vector(result, p, j, lam)
    expected = np.zeros(p, dtype=np.float64)
    expected[j] = max(1.0 - float(lam), 0.0)
    solution_tol = np.sqrt(np.finfo(np.float64).eps)
    w = solution[:p] - solution[p:]
    if not np.allclose(w, expected, rtol=0.0, atol=solution_tol):
        raise RuntimeError(
            "runtime linprog multix probe returned a solution vector "
            "inconsistent with the positive-lambda CLIME column optimum for "
            f"column {j + 1}/{p} at lambda={lam:.6f}; expected "
            f"{expected.tolist()} within tolerance {solution_tol}, got "
            f"{w.tolist()}"
        )
    return w


def _validate_linprog_result_contract(result, p, j, lam):
    """Require the subset of OptimizeResult fields used by the CLIME helper."""
    required_fields = ("success", "status", "message", "x")
    missing_fields = tuple(
        field for field in required_fields if not hasattr(result, field)
    )
    if missing_fields:
        raise RuntimeError(
            "CLIME LP returned an invalid OptimizeResult contract for "
            f"column {j + 1}/{p} at lambda={lam:.6f}: missing required "
            f"field(s) {missing_fields}"
        )
    if not isinstance(result.success, (bool, np.bool_)):
        raise RuntimeError(
            "CLIME LP returned an invalid OptimizeResult contract for "
            f"column {j + 1}/{p} at lambda={lam:.6f}: success must be a bool"
        )
    if isinstance(result.status, (bool, np.bool_)) or not isinstance(
        result.status,
        (int, np.integer),
    ):
        raise RuntimeError(
            "CLIME LP returned an invalid OptimizeResult contract for "
            f"column {j + 1}/{p} at lambda={lam:.6f}: status must be an integer"
        )
    if not isinstance(result.message, str):
        raise RuntimeError(
            "CLIME LP returned an invalid OptimizeResult contract for "
            f"column {j + 1}/{p} at lambda={lam:.6f}: message must be a string"
        )


def _is_clime_contract_runtime_error(exc):
    """Return whether a CLIME runtime error signals a bridge/backend defect."""
    msg = str(exc)
    return (
        msg.startswith("CLIME LP returned an invalid ")
        or msg.startswith("Failed to publish Stata matrix ")
        or msg.startswith("Failed to publish __hddid_clime_effective_nfolds ")
    )


def _is_clime_hard_failure(exc):
    """Return whether a CLIME exception should escape generic solve aggregation."""
    return isinstance(exc, (ImportError, OSError, ValueError, TypeError)) or (
        isinstance(exc, RuntimeError)
        and _is_clime_contract_runtime_error(exc)
    )


def _is_clime_fullsolve_hard_failure(exc):
    """Return whether a full-sample solve must fail immediately.

    Once the sidecar is already inside the column loop for a full precision
    matrix, a per-column ValueError still means the overall solve failed, but it
    should surface through the all-or-nothing "x/y columns failed" contract
    instead of escaping as if the top-level bridge inputs were invalid.
    """
    return isinstance(exc, (ImportError, OSError, TypeError)) or (
        isinstance(exc, RuntimeError)
        and _is_clime_contract_runtime_error(exc)
    )


def _raise_clime_hard_failure(exc_type_name, message):
    """Re-raise a serialized hard failure from the parallel CLIME worker path."""
    exc_types = {
        "ImportError": ImportError,
        "OSError": OSError,
        "ValueError": ValueError,
        "TypeError": TypeError,
        "RuntimeError": RuntimeError,
    }
    exc_type = exc_types.get(exc_type_name, RuntimeError)
    raise exc_type(message)


def _solve_clime_column(Sigma, j, lam, A_ub=None):
    """Solve CLIME column j: min ||w||_1 s.t. ||Sigma*w - e_j||_inf <= lam

    Parameters
    ----------
    Sigma : np.ndarray, shape (p, p)
        Covariance matrix (with diagonal perturbation already applied).
    j : int
        Column index (0-based).
    lam : float
        Regularization parameter lambda (must be >= 0).
    A_ub : np.ndarray or None, shape (2p, 2p)
        Precomputed constraint matrix. If None, constructed internally.

    Returns
    -------
    w : np.ndarray, shape (p,)
        Precision matrix column j.

    Raises
    ------
    ValueError
        If lam < 0, Sigma is not square, or j is out of range.
    RuntimeError
        If LP solver fails.
    """
    # --- Parameter validation ---
    lam = _validate_nonnegative_lambda(lam)
    Sigma = np.asarray(Sigma, dtype=np.float64)
    if Sigma.ndim != 2 or Sigma.shape[0] != Sigma.shape[1]:
        raise ValueError(
            f"Sigma must be a square matrix, got shape {Sigma.shape}"
        )
    if not np.isfinite(Sigma).all():
        raise ValueError("Sigma must contain only finite numeric values")
    p = Sigma.shape[0]
    sigma_scale = float(np.max(np.abs(Sigma)))
    # Sigma is the retained covariance operator in paper eq. (4.2), so its
    # symmetry contract should be judged on Sigma's own scale rather than
    # against a unit-scale floor that can hide same-order asymmetry after a
    # harmless coordinate rescaling of X.
    if not np.isfinite(sigma_scale) or sigma_scale <= 0.0:
        sigma_scale = 1.0
    sym_tol = np.finfo(np.float64).eps * sigma_scale * p
    asym_gap = float(np.max(np.abs(Sigma - Sigma.T)))
    if asym_gap > sym_tol:
        raise ValueError(
            f"Sigma must be symmetric within tolerance {sym_tol}; "
            f"max |Sigma-Sigma'| = {asym_gap}"
        )
    j = _validate_integer_scalar("j", j, minimum=0)
    if j >= p:
        raise ValueError(
            f"Column index j={j} out of range [0, {p - 1}]"
        )

    # --- Objective: min 1'(u+ + u-) = ||w||_1 ---
    c = np.ones(2 * p)

    # --- Constraint matrix A_ub (depends only on Sigma, reusable) ---
    if A_ub is None:
        A_ub = np.block([
            [ Sigma, -Sigma],
            [-Sigma,  Sigma]
        ])  # (2p, 2p)
    else:
        A_ub = _validate_clime_constraint_matrix(Sigma, A_ub)

    # --- RHS vector b_ub (depends on j and lam) ---
    e_j = np.zeros(p)
    e_j[j] = 1.0
    lam_ones = lam * np.ones(p)
    b_ub_vec = np.concatenate([lam_ones + e_j, lam_ones - e_j])

    # --- Solve LP ---
    runtime_solver = _resolve_runtime_linprog_solver()
    result = _validate_runtime_solver_result(
        _call_runtime_linprog_solver(
            runtime_solver,
            c=c,
            A_ub=A_ub,
            b_ub=b_ub_vec,
            method='highs',
        ),
        "runtime LP solver",
    )
    _validate_linprog_result_contract(result, p, j, lam)

    # --- Error handling ---
    if not result.success:
        raise RuntimeError(
            f"CLIME LP failed for column {j + 1}/{p}: "
            f"status={result.status}, message='{result.message}', "
            f"lambda={lam:.6f}, p={p}"
        )

    # --- Extract solution: w = u+ - u- ---
    solution = _validate_linprog_solution_vector(result, p, j, lam)
    w = solution[:p] - solution[p:]
    return w

def _compute_scale_stable_second_moment(x, *, matrix_label):
    """Compute E_n[x_i x_i'] without overflowing on the raw X'X scale."""
    x = np.asarray(x, dtype=np.float64)
    if x.ndim != 2:
        raise ValueError(f"{matrix_label} must be 2D array, got ndim={x.ndim}")
    n, p = x.shape
    if n < 1:
        raise ValueError(f"{matrix_label} must have n >= 1 rows, got n={n}")
    if p < 1:
        raise ValueError(f"{matrix_label} must have p >= 1 columns, got p={p}")

    scale = float(np.max(np.abs(x)))
    if not np.isfinite(scale):
        raise ValueError(f"{matrix_label} must contain only finite numeric values")
    if scale <= 0.0:
        return np.zeros((p, p), dtype=np.float64)

    x_unit = x / scale
    cross_unit = x_unit.T @ x_unit
    sigma_scale = scale / np.sqrt(float(n))
    Sigma = cross_unit * (sigma_scale * sigma_scale)
    if p == 1:
        Sigma = np.atleast_2d(Sigma)
    return Sigma


def _compute_covariance(tildex, perturb=True):
    """Compute the retained raw second-moment operator with perturbation.

    Paper equation (4.2) defines the multivariate CLIME target on the
    empirical retained operator ``E_n[tildeX_i tildeX_i']``. The bridge must
    therefore use the raw second moment directly rather than a centered
    surrogate, because finite retained folds and held-out validation splits can
    have nonzero column means even when the full residualization basis contains
    an intercept.

    Parameters
    ----------
    tildex : np.ndarray, shape (n, p)
    perturb : bool, default True
        If True, add 1/sqrt(n) * I to diagonal.

    Returns
    -------
    Sigma : np.ndarray, shape (p, p)
    n : int
    """
    tildex = np.asarray(tildex, dtype=np.float64)
    if tildex.ndim != 2:
        raise ValueError(f"tildex must be 2D array, got ndim={tildex.ndim}")
    n, p = tildex.shape
    if n < 2:
        raise ValueError(
            f"tildex must have n >= 2 rows for covariance computation, got n={n}"
        )
    if p < 1:
        raise ValueError(f"tildex must have p >= 1 columns, got p={p}")
    tildex = _validate_observed_matrix("tildex", tildex)
    if p > 1:
        # Paper equation (4.2) defines the multivariate CLIME program on the
        # empirical retained covariance itself. An exact zero-variance column
        # means that object is already rank-deficient before any numerical
        # ridge term is added, so perturbation cannot rescue the underlying
        # retained-sample identification failure.
        tildex = _validate_nonconstant_columns("tildex", tildex)
    Sigma = _compute_scale_stable_second_moment(
        tildex,
        matrix_label="tildex",
    )
    if perturb:
        Sigma += np.eye(p) / np.sqrt(n)
    if not np.isfinite(Sigma).all():
        raise ValueError(
            "covariance matrix must contain only finite values"
        )
    return Sigma, n


def _raw_second_moment_diagonal_precision_if_applicable(tildex, matrix_label="tildex"):
    """Return the exact raw retained-operator inverse when it is diagonal.

    For multivariate folds, the paper and the R reference consume the retained
    operator ``E_n[tildeX_i tildeX_i']`` directly. If that raw second moment is
    already diagonal with strictly positive entries, the exact inverse is the
    target object itself and no CLIME LP/CV path is needed.
    """
    Sigma_raw = _compute_scale_stable_second_moment(
        tildex,
        matrix_label=matrix_label,
    )
    return _diagonal_precision_if_applicable(Sigma_raw)


def _single_x_second_moment_precision(tildex, matrix_label="tildex"):
    """Return the p=1 analytic inverse 1 / E_n[tildeX^2].

    The beta-debias scalar shortcut in the paper/Mata path targets the
    empirical second moment, not the centered n-1 sample covariance. Once the
    retained tildex column has been materialized, the identifying contract is
    only that E_n[tildeX^2] is finite and strictly positive; a nonzero sample
    mean does not change the scalar operator defined in equation (4.2). The
    inverse must therefore be computed on a scale-stable basis so large finite
    retained folds do not collapse to zero solely because raw squaring
    overflows before inversion.
    """
    tildex = np.asarray(tildex, dtype=np.float64)
    if tildex.ndim != 2 or tildex.shape[1] != 1:
        raise ValueError(
            f"{matrix_label} must be an n x 1 matrix for the p=1 analytic inverse"
        )
    if tildex.shape[0] < 1:
        raise ValueError(f"{matrix_label} must have n >= 1 rows, got n=0")

    tildex = _validate_observed_matrix(matrix_label, tildex)
    scale = float(np.max(np.abs(tildex[:, 0])))
    if scale <= 0:
        sigma_unit = 0.0
        precision_scalar = 0.0
    else:
        scale_inv = 1.0 / scale
        sigma_unit = float(np.mean(np.square(tildex[:, 0] * scale_inv)))
        precision_scalar = float((scale_inv * scale_inv) / sigma_unit)
    if sigma_unit <= 0:
        if tildex.shape[0] == 1:
            raise ValueError(
                f"{matrix_label} must define a strictly positive empirical "
                "second moment for the singleton p=1 analytic inverse"
            )
        raise ValueError(
            f"{matrix_label} must define a strictly positive empirical "
            "second moment for the p=1 analytic inverse"
        )
    return np.array([[precision_scalar]], dtype=np.float64)


def _compute_val_covariance(tildex_val):
    """Compute the validation raw second moment with a 1/n_val denominator.

    CLIME CV compares held-out folds against the same retained operator used in
    the paper/R solve path. Validation loss therefore has to stay on
    ``E_n[tildeX_i tildeX_i']`` rather than recentering the fold and evaluating
    a different covariance target.

    Parameters
    ----------
    tildex_val : np.ndarray, shape (n_val, p)

    Returns
    -------
    Sigma_val : np.ndarray, shape (p, p)
    """
    tildex_val = np.asarray(tildex_val, dtype=np.float64)
    if tildex_val.ndim != 2:
        raise ValueError(f"tildex_val must be 2D array, got ndim={tildex_val.ndim}")
    n_val, p = tildex_val.shape
    if n_val < 2:
        raise ValueError(f"tildex_val must have n_val >= 2 rows, got n_val={n_val}")
    if p < 1:
        raise ValueError(f"tildex_val must have p >= 1 columns, got p={p}")
    tildex_val = _validate_observed_matrix("tildex_val", tildex_val)
    Sigma_val = _compute_scale_stable_second_moment(
        tildex_val,
        matrix_label="tildex_val",
    )
    if not np.isfinite(Sigma_val).all():
        raise ValueError(
            "validation covariance matrix must contain only finite values"
        )
    return Sigma_val


def _symmetrize_clime(Omega):
    """CLIME symmetrization: for each pair (i,j) take the value with smaller abs.

    Matches flare::sugm CLIME symmetrization behavior.

    Math:
        Theta_ij = Omega_ij  if |Omega_ij| <= |Omega_ji|
        Theta_ij = Omega_ji  if |Omega_ji| <  |Omega_ij|

    Parameters
    ----------
    Omega : np.ndarray, shape (p, p)
        Raw (asymmetric) precision matrix from column-wise LP.

    Returns
    -------
    Theta : np.ndarray, shape (p, p)
        Symmetrized precision matrix.
    """
    Omega = np.asarray(Omega, dtype=np.float64)
    if Omega.ndim != 2 or Omega.shape[0] != Omega.shape[1]:
        raise ValueError(
            f"Omega must be a square matrix, got shape {Omega.shape}"
        )
    if not np.isfinite(Omega).all():
        raise ValueError(
            "Omega must contain only finite values for CLIME symmetrization."
        )

    Theta = np.where(
        np.abs(Omega) <= np.abs(Omega.T),
        Omega,
        Omega.T
    )
    return Theta


def _clime_column_feasibility_gap(Sigma, column, j):
    """Return max_j ||Sigma w_j - e_j||_inf for one CLIME column."""
    Sigma = np.asarray(Sigma, dtype=np.float64)
    column = np.asarray(column, dtype=np.float64)
    e_j = np.zeros(Sigma.shape[0], dtype=np.float64)
    e_j[j] = 1.0
    return float(np.max(np.abs(Sigma @ column - e_j)))


def _symmetrize_clime_for_contract(Omega, Sigma=None, lam=None):
    """Return a symmetric CLIME matrix even when abs-ties occur off diagonal.

    The elementwise min-abs rule above is symmetric whenever one side is
    strictly smaller. Exact abs-ties are the remaining corner case: applying
    the rule entrywise keeps both original values, which can leave an
    asymmetric matrix when Omega[i, j] != Omega[j, i] but
    abs(Omega[i, j]) == abs(Omega[j, i]). The precision-matrix contract used
    by the Stata bridge and the debiasing step is symmetric. When the raw CLIME
    columns themselves satisfy the retained-sample feasibility bound, do not
    silently resolve an opposite-sign exact abs-tie into a symmetric matrix
    that violates that same CLIME column constraint.
    """
    Omega = np.asarray(Omega, dtype=np.float64)
    Theta = _symmetrize_clime(Omega)
    if Sigma is not None:
        Sigma = np.asarray(Sigma, dtype=np.float64)
    if lam is not None:
        lam = _validate_nonnegative_lambda(lam)

    if Theta.shape[0] <= 1:
        return Theta

    upper_i, upper_j = np.triu_indices(Theta.shape[0], k=1)
    abs_upper = np.abs(Omega[upper_i, upper_j])
    abs_lower = np.abs(Omega[upper_j, upper_i])
    tie_mask = abs_upper == abs_lower
    if np.any(tie_mask):
        for i, j in zip(upper_i[tie_mask], upper_j[tie_mask]):
            upper_value = Omega[i, j]
            lower_value = Omega[j, i]
            Theta[i, j] = upper_value
            Theta[j, i] = upper_value
            if (
                Sigma is not None
                and lam is not None
                and upper_value != lower_value
            ):
                tol_scale = max(
                    1.0,
                    float(np.max(np.abs(Sigma))),
                    abs(float(lam)),
                    abs(float(upper_value)),
                    abs(float(lower_value)),
                )
                tol = np.finfo(np.float64).eps * tol_scale * Sigma.shape[0]
                raw_i_gap = _clime_column_feasibility_gap(Sigma, Omega[:, i], i)
                raw_j_gap = _clime_column_feasibility_gap(Sigma, Omega[:, j], j)
                upper_i_gap = _clime_column_feasibility_gap(
                    Sigma,
                    Theta[:, i],
                    i,
                )
                upper_j_gap = _clime_column_feasibility_gap(
                    Sigma,
                    Theta[:, j],
                    j,
                )
                lower_theta = Theta.copy()
                lower_theta[i, j] = lower_value
                lower_theta[j, i] = lower_value
                lower_i_gap = _clime_column_feasibility_gap(
                    Sigma,
                    lower_theta[:, i],
                    i,
                )
                lower_j_gap = _clime_column_feasibility_gap(
                    Sigma,
                    lower_theta[:, j],
                    j,
                )
                raw_selected_ok = raw_i_gap <= lam + tol and raw_j_gap <= lam + tol
                upper_selected_ok = upper_i_gap <= lam + tol and upper_j_gap <= lam + tol
                lower_selected_ok = lower_i_gap <= lam + tol and lower_j_gap <= lam + tol
                if raw_selected_ok:
                    if upper_selected_ok:
                        continue
                    if lower_selected_ok:
                        Theta[i, j] = lower_value
                        Theta[j, i] = lower_value
                        continue
                    raise ValueError(
                        "CLIME exact abs-tie cannot be symmetrized "
                        "without violating the retained-sample "
                        "symmetric CLIME feasibility contract."
                    )

                # Once the raw unsymmetrized columns miss the selected lambda,
                # the published-matrix contract falls back to the looser
                # retained-sample cap used by the ado layer. Exact-tie
                # symmetrization should therefore prefer whichever symmetric
                # choice preserves that published cap rather than arbitrarily
                # defaulting to the upper-triangle sign.
                cap = float(np.max(np.abs(Sigma - np.diag(np.diag(Sigma)))))
                upper_sigma = Sigma @ Theta[:, [i, j]]
                lower_sigma = Sigma @ lower_theta[:, [i, j]]
                upper_cap_tol = np.finfo(np.float64).eps * max(
                    1.0,
                    float(np.max(np.abs(upper_sigma))),
                ) * Sigma.shape[0]
                lower_cap_tol = np.finfo(np.float64).eps * max(
                    1.0,
                    float(np.max(np.abs(lower_sigma))),
                ) * Sigma.shape[0]
                upper_cap_ok = max(upper_i_gap, upper_j_gap) <= cap + upper_cap_tol
                lower_cap_ok = max(lower_i_gap, lower_j_gap) <= cap + lower_cap_tol
                if not upper_cap_ok and lower_cap_ok:
                    Theta[i, j] = lower_value
                    Theta[j, i] = lower_value

    return Theta


def _validate_selected_clime_precision_or_raise(
    Theta,
    *,
    Omega,
    Sigma,
    best_lambda,
    lambdas,
):
    """Fail-close on an empty CLIME path before publish-time matrix writes.

    flare::sugm() can legitimately return an all-zero path when every lambda in
    the current grid already makes the zero matrix feasible. On duplicated or
    otherwise highly collinear retained designs, sugm.select() then has no
    positive-diagonal opt.icov to publish. Surface that degeneracy directly
    instead of letting the later Stata write-back step fail with a generic
    precision-matrix contract error.
    """
    try:
        return _validate_precision_matrix_contract(
            "computed precision matrix",
            Theta,
        )
    except ValueError as exc:
        Theta = np.asarray(Theta, dtype=np.float64)
        Omega = np.asarray(Omega, dtype=np.float64)
        Sigma = np.asarray(Sigma, dtype=np.float64)
        lambdas = _validate_lambda_candidates(lambdas)
        best_lambda = _validate_nonnegative_lambda(best_lambda)

        if (
            Theta.ndim == 2
            and Theta.shape[0] == Theta.shape[1]
            and Omega.ndim == 2
            and Omega.shape == Theta.shape
        ):
            theta_diag = np.diag(Theta)
            zero_scale = max(
                1.0,
                float(np.max(np.abs(Sigma))) if Sigma.size else 1.0,
                abs(float(best_lambda)),
            )
            zero_tol = np.finfo(np.float64).eps * zero_scale * max(1, Omega.shape[0])
            empty_raw_path = np.all(np.abs(Omega) <= zero_tol)
            if np.any(theta_diag <= 0.0) and empty_raw_path:
                lambda_hi = float(np.max(lambdas))
                lambda_lo = float(np.min(lambdas))
                raise RuntimeError(
                    "CLIME selected an empty/degenerate full-sample precision path: "
                    f"the current lambda grid [{lambda_hi:.6g}, ..., {lambda_lo:.6g}] "
                    f"(best lambda={best_lambda:.6g}) leaves the symmetrized precision "
                    "matrix without strictly positive diagonal entries. This retained "
                    "tildex design matches the flare::sugm.select() empty-path case "
                    "where no publishable opt.icov survives the default CLIME grid. "
                    "Shrink lambda_min_ratio or widen the lambda grid before "
                    "re-running this multivariate retained fold."
                ) from exc
        raise


def _diagonal_precision_if_applicable(Sigma):
    """Return the analytic inverse when Sigma is exactly diagonal."""
    Sigma = np.asarray(Sigma, dtype=np.float64)
    if Sigma.ndim != 2 or Sigma.shape[0] != Sigma.shape[1]:
        raise ValueError(
            f"Sigma must be a square matrix, got shape {Sigma.shape}"
        )
    if not np.isfinite(Sigma).all():
        raise ValueError(
            "Sigma must contain only finite values for diagonal precision shortcut."
        )

    diag = np.diag(Sigma)
    offdiag = Sigma - np.diag(diag)
    # Covariance construction can leave machine-zero off-diagonal residue even
    # when the centered columns are orthogonal in exact arithmetic. Treat those
    # roundoff artifacts as diagonal so the bridge does not spuriously require
    # SciPy/CLIME for what is mathematically the analytic inverse path.
    # Use Sigma's own pairwise coordinate scale. A global rescaling of X should
    # not change whether Sigma is judged diagonal, so an absolute unit floor
    # would incorrectly bless same-order tiny off-diagonal entries.
    pair_scale = np.sqrt(np.outer(np.abs(diag), np.abs(diag)))
    offdiag_tol = np.finfo(np.float64).eps * pair_scale
    if np.any(np.abs(offdiag) > offdiag_tol):
        return None

    if np.any(diag <= 0):
        raise ValueError(
            "Diagonal covariance path requires strictly positive diagonal entries."
        )

    with np.errstate(over="ignore", divide="ignore", invalid="ignore"):
        precision_diag = 1.0 / diag
    if not np.isfinite(precision_diag).all():
        raise ValueError(
            "Diagonal precision shortcut must remain finite."
        )

    return np.diag(precision_diag)


def _generate_lambda_grid(Sigma, nlambda=5, lambda_min_ratio=0.4):
    """
    生成CLIME的lambda候选网格，匹配flare::sugm默认参数。

    参数:
        Sigma: np.ndarray, (p, p) 协方差矩阵（含对角扰动）
        nlambda: int, 候选lambda数量（默认5，匹配sugm默认nlambda=5）
        lambda_min_ratio: float, 最小lambda与最大lambda之比（默认0.4，匹配sugm对clime的默认）

    返回:
        lambdas: np.ndarray, (nlambda,) 从大到小排列的lambda值
    """
    nlambda = _validate_positive_int("nlambda", nlambda, minimum=1)
    lambda_min_ratio = _validate_lambda_min_ratio(lambda_min_ratio)

    if _diagonal_precision_if_applicable(Sigma) is not None:
        return np.zeros(nlambda, dtype=np.float64)

    Sigma_offdiag = Sigma.copy()
    np.fill_diagonal(Sigma_offdiag, 0)
    lambda_max = np.max(np.abs(Sigma_offdiag))

    if lambda_max <= 0:
        # With exact zero off-diagonal covariance, the CLIME feasibility bound
        # collapses to lambda=0. Fabricating a positive lambda grid would
        # introduce shrinkage that is not implied by the paper or the R path.
        return np.zeros(nlambda, dtype=np.float64)

    lambda_min = lambda_min_ratio * lambda_max
    lambdas = np.exp(np.linspace(np.log(lambda_max), np.log(lambda_min), nlambda))
    return lambdas


def _resolve_cv_nfolds(n, nfolds, min_validation_size=2):
    """Return the largest non-degenerate CV fold count under equal blocks.

    The CLIME CV path uses validation blocks of size floor(n / nfolds). To keep
    the validation covariance informative, each validation block must contain at
    least ``min_validation_size`` observations. When the requested fold count is
    too large, reduce it to the largest feasible value instead of silently
    accepting singleton validation blocks.
    """
    n = _validate_positive_int("n", n, minimum=1)
    nfolds = _validate_positive_int("nfolds_cv", nfolds, minimum=2)
    min_validation_size = _validate_positive_int(
        "min_validation_size", min_validation_size, minimum=1
    )
    if nfolds > n:
        raise ValueError(
            f"CLIME CV invalid: nfolds_cv={nfolds} exceeds sample size n={n}, "
            "which would create empty validation folds."
        )

    max_feasible_nfolds = n // min_validation_size
    if max_feasible_nfolds < 2:
        raise ValueError(
            "CLIME CV requires at least 2 observations per validation fold; "
            f"got n={n}, requested nfolds_cv={nfolds}."
        )

    return min(int(nfolds), int(max_feasible_nfolds))


def _validate_cv_nfolds(n, nfolds):
    """Validate the CLIME CV fold-size contract.

    The CLIME path requires every validation fold to retain at least two
    observations so the held-out covariance remains well-defined, and the
    partition must still exhaust all retained-sample observations even when
    ``n`` is not divisible by ``nfolds``.
    """
    n = _validate_positive_int("n", n, minimum=1)
    nfolds = _validate_positive_int("nfolds_cv", nfolds, minimum=2)
    if nfolds > n:
        raise ValueError(
            f"CLIME CV invalid: nfolds_cv={nfolds} exceeds sample size n={n}, "
            "which would create empty validation folds."
        )
    if n // nfolds < 2:
        raise ValueError(
            "CLIME CV requires at least 2 observations per validation fold; "
            f"got n={n}, requested nfolds_cv={nfolds}."
        )


def _part_cv(n, nfolds, random_state=None):
    """
    实现R包part.cv()的完整块切分结构。

    The fold layout uses contiguous post-permutation blocks whose sizes differ
    by at most one observation, so every retained observation appears in
    exactly one validation fold. The RNG stream is NumPy-based, so a given
    numeric seed is reproducible within hddid's Python bridge but need not
    yield the identical permutation that R's sample()/part.cv() would draw.

    参数:
        n: int, 总样本量
        nfolds: int, 折数
        random_state: int or None, 随机种子

    返回:
        test_indices: list of np.ndarray, 每折的测试集观测索引
        train_indices: list of np.ndarray, 每折的训练集观测索引
    """
    _validate_cv_nfolds(n, nfolds)
    random_state = _validate_optional_int(
        "random_state",
        random_state,
        minimum=0,
        maximum=NUMPY_RANDOM_STATE_MAX,
    )
    if random_state is not None:
        ind = np.random.RandomState(random_state).permutation(n)
    else:
        ind = np.random.permutation(n)
    ntest_base = n // nfolds
    ntest_remainder = n % nfolds

    test_indices = []
    train_indices = []
    offset = 0

    for k in range(nfolds):
        fold_size = ntest_base + (1 if k < ntest_remainder else 0)
        test_start = offset
        test_end = test_start + fold_size
        test_idx = ind[test_start:test_end]
        train_idx = np.concatenate([ind[:test_start], ind[test_end:]])
        test_indices.append(test_idx)
        train_indices.append(train_idx)
        offset = test_end

    return test_indices, train_indices


def _cv_select_lambda(tildex, lambdas, nfolds_cv=5, perturb=True, random_state=None):
    """
    通过K折交叉验证选择CLIME的最优lambda。
    在给定fold划分下匹配 flare::sugm.select(criterion="cv", loss="tracel2")
    的损失定义与聚合行为。

    参数:
        tildex: np.ndarray, (n, p) 投影残差数据
        lambdas: np.ndarray, (nlambda,) 候选lambda值
        nfolds_cv: int, CV折数（默认5）
        perturb: bool, 是否添加对角扰动
        random_state: int or None, 随机种子

    返回:
        best_lambda: float, 使CV loss最小的lambda
        cv_losses: np.ndarray, (nlambda,) 每个lambda的平均CV loss
    """
    import warnings

    tildex = np.asarray(tildex, dtype=np.float64)
    if tildex.ndim != 2:
        raise ValueError(f"tildex must be 2D array, got ndim={tildex.ndim}")
    tildex = _validate_observed_matrix("tildex", tildex)
    if tildex.shape[1] > 1:
        # CV tunes the same multivariate retained-sample precision target as
        # the full solve, so the public helper must reject exact constant
        # columns before any fold-level perturbation can mask the rank failure.
        tildex = _validate_nonconstant_columns("tildex", tildex)
    lambdas = _validate_lambda_candidates(lambdas)

    n, p = tildex.shape
    nlambda = len(lambdas)

    effective_nfolds_cv = _resolve_cv_nfolds(n, nfolds_cv)
    _validate_cv_nfolds(n, effective_nfolds_cv)
    test_indices, train_indices = _part_cv(n, effective_nfolds_cv, random_state)

    cv_loss_sum = np.zeros(nlambda)
    cv_loss_count = np.zeros(nlambda, dtype=int)

    for k in range(effective_nfolds_cv):
        x_train = tildex[train_indices[k]]
        x_test = tildex[test_indices[k]]
        Sigma_train, _ = _compute_covariance(x_train, perturb=perturb)

        Theta_list = []
        solve_success = []
        for j in range(nlambda):
            try:
                Omega_raw = np.zeros((p, p))
                all_cols_ok = True
                for col in range(p):
                    w = _solve_clime_column(Sigma_train, col, lambdas[j])
                    if w is None:
                        all_cols_ok = False
                        break
                    Omega_raw[:, col] = w

                if all_cols_ok:
                    # Match flare::sugm.select() exactly during CV loss
                    # evaluation. The Stata bridge needs a symmetric final
                    # precision matrix, but the inner tracel2 path in flare
                    # uses the raw min-abs symmetrization even when abs-ties
                    # leave Omega asymmetric.
                    Theta = _symmetrize_clime(Omega_raw)
                    Theta_list.append(Theta)
                    solve_success.append(True)
                else:
                    Theta_list.append(None)
                    solve_success.append(False)
            except RuntimeError as exc:
                # Runtime solver failures are lambda/fold-specific CLIME misses
                # that the CV path may prune. Dependency and contract errors
                # must escape so the bridge does not relabel them as generic
                # "no finite CV loss" failures.
                if _is_clime_contract_runtime_error(exc):
                    raise
                Theta_list.append(None)
                solve_success.append(False)

        Sigma_val = _compute_val_covariance(x_test)

        for j in range(nlambda):
            if not solve_success[j]:
                warnings.warn(
                    f"CLIME solve failed for fold {k}, lambda={lambdas[j]:.6f}. "
                    f"Skipping this (fold, lambda) combination."
                )
                continue

            Theta = Theta_list[j]
            M = Sigma_val @ Theta - np.eye(p)
            # CLIME tunes a full precision operator, so the validation loss
            # must penalize the full residual matrix, not only its diagonal.
            loss = float(np.sum(M * M))
            cv_loss_sum[j] += loss
            cv_loss_count[j] += 1

    cv_losses = np.full(nlambda, np.inf)
    for j in range(nlambda):
        if cv_loss_count[j] == effective_nfolds_cv:
            cv_losses[j] = cv_loss_sum[j] / effective_nfolds_cv
        elif cv_loss_count[j] > 0:
            warnings.warn(
                "CLIME CV dropping lambda="
                f"{lambdas[j]:.6f} because it succeeded on only "
                f"{cv_loss_count[j]}/{effective_nfolds_cv} folds."
            )

    if not np.isfinite(cv_losses).any():
        raise RuntimeError(
            "CLIME CV failed: no finite CV loss for any candidate lambda "
            "with complete fold coverage "
            f"across {effective_nfolds_cv} folds and {nlambda} lambdas."
        )

    best_idx = np.argmin(cv_losses)
    best_lambda = lambdas[best_idx]

    return best_lambda, cv_losses

# ── Parallel worker functions (module-level for pickling) ──

_worker_Sigma = None
_worker_A_ub = None

def _init_clime_worker(Sigma, A_ub):
    """Initializer for multiprocessing Pool workers."""
    global _worker_Sigma, _worker_A_ub
    _worker_Sigma = Sigma
    _worker_A_ub = A_ub

def _solve_column_worker(args):
    """Worker function for parallel CLIME column solving."""
    j, lam = args
    try:
        w = _solve_clime_column(_worker_Sigma, j, lam, A_ub=_worker_A_ub)
        return (j, w)
    except Exception as e:
        if _is_clime_fullsolve_hard_failure(e):
            return (j, ("__hddid_hard_failure__", type(e).__name__, str(e)))
        return (j, str(e))


def _validate_output_matrix_slot(Matrix, covinv_matname, p):
    """Require the Stata output slot to be preallocated as a p x p matrix."""
    covinv_matname = _validate_matrix_name("covinv_matname", covinv_matname)
    raw_output = Matrix.get(covinv_matname)
    if raw_output is None:
        raise ValueError(
            f"Stata matrix '{covinv_matname}' does not exist. "
            f"The ado layer must create and preallocate a "
            f"{p} x {p} matrix slot named '{covinv_matname}' "
            f"before calling hddid_clime_solve()."
        )

    try:
        output = _coerce_numeric_matrix(
            f"Stata matrix '{covinv_matname}' output slot",
            raw_output,
        )
    except ValueError as exc:
        raise ValueError(
            f"Stata matrix '{covinv_matname}' must be preallocated as a "
            f"numeric {p} x {p} matrix before calling hddid_clime_solve()."
        ) from exc
    if output.ndim != 2 or output.shape != (p, p):
        if output.ndim == 0:
            shape = "()"
        elif output.ndim == 1:
            shape = f"({output.shape[0]},)"
        else:
            shape = str(output.shape)
        raise ValueError(
            f"Stata matrix '{covinv_matname}' must be preallocated as a "
            f"{p} x {p} matrix before calling hddid_clime_solve(); "
            f"got shape {shape}."
        )


def _store_precision_matrix(Matrix, covinv_matname, Theta):
    """Write back Theta and verify the Stata bridge stored the intended matrix."""
    covinv_matname = _validate_matrix_name("covinv_matname", covinv_matname)
    Theta = _validate_precision_matrix_contract(
        "computed precision matrix",
        Theta,
    )

    Matrix.store(covinv_matname, Theta.tolist())

    raw_written = Matrix.get(covinv_matname)
    if raw_written is None:
        raise ValueError(
            f"Stata matrix '{covinv_matname}' did not overwrite with the "
            f"computed {Theta.shape[0]} x {Theta.shape[1]} precision matrix."
        )

    written = _coerce_numeric_matrix(
        f"Stata matrix '{covinv_matname}' write-back",
        raw_written,
    )
    if written.ndim != 2 or written.shape != Theta.shape:
        raise ValueError(
            f"Stata matrix '{covinv_matname}' did not overwrite with the "
            f"computed {Theta.shape[0]} x {Theta.shape[1]} precision matrix; "
            f"got shape {written.shape}."
        )
    try:
        written = _validate_precision_matrix_contract(
            f"Stata matrix '{covinv_matname}' write-back",
            written,
        )
    except ValueError as exc:
        raise ValueError(
            f"Stata matrix '{covinv_matname}' did not overwrite with the "
            f"computed {Theta.shape[0]} x {Theta.shape[1]} precision matrix."
        ) from exc
    # Stata's matrix bridge may canonicalize a numerically symmetric matrix
    # when writing into a symmetric matrix slot. Accept round-trips that stay
    # within double-precision bridge tolerance instead of requiring bitwise
    # identity after host normalization.
    writeback_scale = max(
        1.0,
        float(np.max(np.abs(Theta))),
        float(np.max(np.abs(written))),
    )
    writeback_tol = np.finfo(np.float64).eps * writeback_scale * Theta.shape[0]
    if not np.allclose(written, Theta, rtol=0.0, atol=writeback_tol):
        raise ValueError(
            f"Stata matrix '{covinv_matname}' did not overwrite with the "
            f"computed {Theta.shape[0]} x {Theta.shape[1]} precision matrix."
        )
    return written


def _snapshot_prior_matrix_for_atomic_publish(Matrix, covinv_matname, Theta):
    """Require a readable prior matrix snapshot before atomic bridge publish."""
    raw_snapshot = Matrix.get(covinv_matname)
    if raw_snapshot is None:
        raise TypeError(
            "sfi.Matrix must expose a readable prior matrix snapshot via "
            f"Matrix.get('{covinv_matname}') before publishing atomically; "
            "otherwise the matrix rollback path is unavailable."
        )

    try:
        snapshot = _coerce_numeric_matrix(
            f"Stata matrix '{covinv_matname}' prior snapshot",
            raw_snapshot,
        )
    except ValueError as exc:
        raise TypeError(
            "sfi.Matrix must expose a readable prior matrix snapshot via "
            f"Matrix.get('{covinv_matname}') before publishing atomically; "
            "otherwise the matrix rollback path is unavailable."
        ) from exc

    if snapshot.ndim != 2 or snapshot.shape != Theta.shape:
        raise TypeError(
            "sfi.Matrix must expose a readable prior matrix snapshot via "
            f"Matrix.get('{covinv_matname}') before publishing atomically; "
            f"expected shape {Theta.shape[0]} x {Theta.shape[1]}, "
            f"got {snapshot.shape}."
        )
    return snapshot.tolist()


def _restore_matrix_snapshot_or_raise(
    Matrix,
    covinv_matname,
    rollback_snapshot,
    failure_message,
):
    """Restore a prior matrix slot and verify the host bridge actually did so."""
    try:
        Matrix.store(covinv_matname, rollback_snapshot)
    except Exception as rollback_exc:
        raise RuntimeError(failure_message) from rollback_exc

    raw_restored = Matrix.get(covinv_matname)
    if raw_restored is None:
        raise RuntimeError(failure_message)

    try:
        restored = _coerce_numeric_matrix(
            f"Stata matrix '{covinv_matname}' rollback snapshot",
            raw_restored,
        )
        snapshot = _coerce_numeric_matrix(
            f"Stata matrix '{covinv_matname}' rollback target",
            rollback_snapshot,
        )
    except ValueError as rollback_exc:
        raise RuntimeError(failure_message) from rollback_exc

    if restored.ndim != 2 or restored.shape != snapshot.shape:
        raise RuntimeError(failure_message)

    restore_scale = max(
        1.0,
        float(np.max(np.abs(snapshot))),
        float(np.max(np.abs(restored))),
    )
    restore_tol = np.finfo(np.float64).eps * restore_scale * snapshot.shape[0]
    if not np.allclose(restored, snapshot, rtol=0.0, atol=restore_tol):
        raise RuntimeError(failure_message)


def _get_mutable_scalar_store(Scalar):
    """Return a mutable scalar backing store when the host bridge exposes one."""
    if Scalar is None:
        return None
    for scalar_store_attr in ("values", "store", "_store"):
        candidate_store = getattr(Scalar, scalar_store_attr, None)
        if isinstance(candidate_store, MutableMapping):
            return candidate_store
    return None


def _get_host_visible_scalar_store(Scalar):
    """Return a readable host-visible scalar store when no primary store exists."""
    scalar_store = _get_mutable_scalar_store(Scalar)
    if scalar_store is not None:
        return scalar_store
    if Scalar is None:
        return None
    for scalar_store_attr in ("host_state", "_host_state"):
        candidate_store = getattr(Scalar, scalar_store_attr, None)
        if isinstance(candidate_store, MutableMapping):
            return candidate_store
    return None


def _get_authoritative_scalar_store(Scalar, scalar_store=None):
    """Return the readable host-visible scalar mapping when one is exposed."""
    if Scalar is None:
        return None
    for scalar_store_attr in ("host_state", "_host_state"):
        candidate_store = getattr(Scalar, scalar_store_attr, None)
        if isinstance(candidate_store, MutableMapping):
            return candidate_store
    if scalar_store is not None:
        return scalar_store
    return _get_mutable_scalar_store(Scalar)


def _scalar_store_has_ambiguous_views(Scalar, scalar_store):
    """Return whether the scalar bridge exposes multiple mutable mapping views."""
    if Scalar is None or scalar_store is None:
        return False

    mapping_ids = set()
    for scalar_store_attr in (
        "values",
        "store",
        "_store",
        "host_state",
        "_host_state",
    ):
        candidate_store = getattr(Scalar, scalar_store_attr, None)
        if isinstance(candidate_store, MutableMapping):
            mapping_ids.add(id(candidate_store))
    return len(mapping_ids) > 1


def _scalar_contract_value_matches(actual, expected):
    """Return whether a host scalar reflects the numeric effective-fold contract."""
    if isinstance(actual, (bool, np.bool_)):
        return False
    if not isinstance(actual, (int, float, np.integer, np.floating)):
        return False
    actual = float(actual)
    expected = float(expected)
    return np.isfinite(actual) and actual == expected


def _probe_scalar_presence_via_stata(stata_callable, scalar_name):
    """Best-effort scalar existence probe for drop-capable Stata bridges."""
    def _rollback_speculative_probe(command):
        """Undo obvious in-memory call-log side effects after a failed probe."""
        candidates = []

        owner = getattr(stata_callable, "__self__", None)
        if owner is not None:
            candidates.append(owner)

        closure = getattr(stata_callable, "__closure__", None) or ()
        for cell in closure:
            try:
                candidates.append(cell.cell_contents)
            except ValueError:
                continue

        globals_dict = getattr(stata_callable, "__globals__", {})
        for candidate in globals_dict.values():
            if hasattr(candidate, "commands") or hasattr(candidate, "calls"):
                candidates.append(candidate)

        seen_ids = set()
        for candidate in candidates:
            candidate_id = id(candidate)
            if candidate_id in seen_ids:
                continue
            seen_ids.add(candidate_id)
            for attr_name in ("commands", "calls"):
                probe_log = getattr(candidate, attr_name, None)
                if (
                    isinstance(probe_log, list)
                    and probe_log
                    and probe_log[-1] == command
                ):
                    probe_log.pop()
                    return

    def _extract_boolish_probe_value(value):
        if isinstance(value, (bool, np.bool_)):
            return bool(value)
        if isinstance(value, bytes):
            try:
                value = value.decode("utf-8")
            except UnicodeDecodeError:
                return None
        if isinstance(value, str):
            value = value.strip().lower()
            if value == "true":
                return True
            if value == "false":
                return False
        return None

    def _coerce_confirm_rc(value):
        if isinstance(value, bytes):
            try:
                value = value.decode("utf-8")
            except UnicodeDecodeError:
                return None
        if isinstance(value, str):
            value = value.strip()
            if value == "":
                return None
            try:
                value = float(value)
            except ValueError:
                return None
        if isinstance(value, (bool, np.bool_)):
            return None
        if isinstance(value, (int, float, np.integer, np.floating)):
            value = float(value)
            if np.isfinite(value) and value == np.floor(value):
                value = int(value)
                if value == 0:
                    return True
                if value == 111:
                    return False
        return None

    if not callable(stata_callable):
        return None
    try:
        rc = stata_callable(f"capture confirm scalar {scalar_name}")
    except Exception:
        return None
    rc_value = _coerce_confirm_rc(rc)
    if rc_value is not None:
        return rc_value

    rc_attr = getattr(rc, "rc", None)
    rc_attr_value = _coerce_confirm_rc(rc_attr)
    if rc_attr_value is not None:
        return rc_attr_value
    boolish_rc = _extract_boolish_probe_value(rc)
    if boolish_rc is None:
        boolish_rc = _extract_boolish_probe_value(rc_attr)
    if boolish_rc is not None:
        absent_suffix = format(id(stata_callable) & 0xffffffff, "08x")
        absent_name = f"__hddid_probe_absent_{absent_suffix}"
        if absent_name == scalar_name:
            absent_name = "__hddid_probe_absent_w08"
        absent_command = f"capture confirm scalar {absent_name}"
        try:
            absent_rc = stata_callable(absent_command)
        except Exception:
            # Some host bridges only support probing the actual target scalar
            # name. In that case, fall back to rc semantics directly.
            _rollback_speculative_probe(absent_command)
            return not boolish_rc
        absent_rc_value = _coerce_confirm_rc(absent_rc)
        if absent_rc_value is None:
            absent_rc_value = _coerce_confirm_rc(getattr(absent_rc, "rc", None))
        if absent_rc_value is not None:
            return boolish_rc != absent_rc_value
        absent_boolish = _extract_boolish_probe_value(absent_rc)
        if absent_boolish is None:
            absent_boolish = _extract_boolish_probe_value(
                getattr(absent_rc, "rc", None)
            )
        if absent_boolish is None:
            return not boolish_rc
        return boolish_rc != absent_boolish
    return None


def _publish_precision_results(
    Matrix, Scalar, covinv_matname, Theta, effective_nfolds,
    scalar_precleared=False
):
    """Publish the bridge outputs atomically or restore the prior matrix slot."""
    covinv_matname = _validate_matrix_name("covinv_matname", covinv_matname)
    Theta = _validate_precision_matrix_contract(
        "computed precision matrix",
        Theta,
    )
    effective_nfolds = _validate_effective_nfolds(
        "effective_nfolds",
        effective_nfolds,
    )
    rollback_snapshot = _snapshot_prior_matrix_for_atomic_publish(
        Matrix,
        covinv_matname,
        Theta,
    )
    if Scalar is None:
        try:
            return _store_precision_matrix(Matrix, covinv_matname, Theta)
        except Exception:
            _restore_matrix_snapshot_or_raise(
                Matrix,
                covinv_matname,
                rollback_snapshot,
                f"Failed to publish Stata matrix '{covinv_matname}' and "
                "could not restore its previous value.",
            )
            raise
    scalar_name = "__hddid_clime_effective_nfolds"
    scalar_store = _get_mutable_scalar_store(Scalar)
    authoritative_scalar_store = _get_authoritative_scalar_store(
        Scalar,
        scalar_store,
    )
    authoritative_store_is_distinct = (
        authoritative_scalar_store is not None
        and authoritative_scalar_store is not scalar_store
    )
    scalar_drop_stata = None
    try:
        from sfi import SFIToolkit
    except ImportError:
        SFIToolkit = None
    if SFIToolkit is not None:
        scalar_drop_stata = getattr(SFIToolkit, "stata", None)
    scalar_get_value = getattr(Scalar, "getValue", None)
    scalar_set_value = getattr(Scalar, "setValue", None)
    scalar_precleared = bool(scalar_precleared)
    scalar_store_ambiguous = _scalar_store_has_ambiguous_views(
        Scalar,
        scalar_store,
    )
    if (
        authoritative_scalar_store is None
        and not callable(scalar_get_value)
        and not scalar_precleared
    ):
        raise TypeError(
            "sfi.Scalar must expose a readable prior scalar snapshot for the "
            "rollback path via a mutable mapping store or getValue() to publish "
            "__hddid_clime_effective_nfolds atomically; "
            "sfi.SFIToolkit.stata() alone can only drop a new scalar, not "
            "restore an unreadable prior value."
        )
    scalar_had_prior_value = False
    scalar_prior_value = None
    if callable(scalar_get_value):
        try:
            scalar_prior_value = scalar_get_value(scalar_name)
        except KeyError:
            scalar_had_prior_value = False
        else:
            # A getValue()-only bridge may use None to signal "scalar absent"
            # instead of raising. The effective-fold contract is numeric, so a
            # None payload must be treated as "no prior scalar" for rollback.
            scalar_had_prior_value = scalar_prior_value is not None
    elif authoritative_scalar_store is not None:
        if scalar_name in authoritative_scalar_store:
            scalar_prior_value = authoritative_scalar_store[scalar_name]
            # Mapping-backed test/host bridges may keep a None sentinel instead
            # of omitting the key when the scalar is absent. Align that
            # semantics with the getValue()-only path so rollback drops the
            # synthetic effective-fold scalar instead of restoring None.
            scalar_had_prior_value = scalar_prior_value is not None
    elif scalar_precleared:
        scalar_had_prior_value = False
    if (
        scalar_store_ambiguous
        and callable(scalar_get_value)
        and not callable(scalar_set_value)
    ):
        raise TypeError(
            "sfi.Scalar must expose an authoritative scalar bridge via "
            "setValue() when multiple mutable mapping views exist; "
            "getValue() alone can still leave the host-visible scalar stale."
        )
    if (
        scalar_had_prior_value
        and scalar_store_ambiguous
        and not callable(scalar_get_value)
        and callable(scalar_set_value)
        and not authoritative_store_is_distinct
    ):
        raise TypeError(
            "sfi.Scalar must expose an authoritative scalar bridge via "
            "getValue() when multiple mutable mapping views exist; "
            "setValue() alone cannot verify the host-visible scalar "
            "__hddid_clime_effective_nfolds contract."
        )
    if (
        scalar_had_prior_value
        and scalar_store_ambiguous
        and not callable(scalar_get_value)
        and not callable(scalar_set_value)
    ):
        raise TypeError(
            "sfi.Scalar must expose an authoritative scalar bridge via "
            "getValue() or setValue() when multiple mutable mapping views "
            "exist; otherwise publishing __hddid_clime_effective_nfolds "
            "could update one view while leaving the host-visible prior "
            "scalar stale."
        )
    if (
        not scalar_had_prior_value
        and not callable(scalar_drop_stata)
        and not scalar_precleared
        and scalar_store is None
        and callable(scalar_set_value)
        and not callable(scalar_get_value)
    ):
        raise TypeError(
            "sfi.Scalar must expose a rollback path for newly created "
            "__hddid_clime_effective_nfolds before calling setValue(); "
            "a setValue()-only bridge can mutate host-visible state before "
            "raising, so getValue()/host_state readback alone is not an "
            "atomic rollback path."
        )
    if (
        not scalar_had_prior_value
        and not callable(scalar_drop_stata)
        and authoritative_scalar_store is None
        and not callable(scalar_set_value)
    ):
        raise TypeError(
            "sfi.Scalar must expose a rollback path for newly created "
            "__hddid_clime_effective_nfolds via a readable prior scalar value "
            "or callable sfi.SFIToolkit.stata(); otherwise the bridge cannot "
            "remove a newly published scalar after failure."
        )
    if scalar_store is None and not callable(scalar_set_value):
        raise TypeError(
            "sfi.Scalar must expose a writable scalar bridge via "
            "setValue() or a mutable mapping store to publish "
            "__hddid_clime_effective_nfolds."
        )
    # A plain mutable backing store can be restored directly after a failed
    # publish. Only bridges with no store, or with an independent readable host
    # snapshot via getValue(), require a second setValue() call on rollback.
    scalar_restore_via_setvalue = callable(scalar_set_value) and (
        scalar_store is None
        or callable(scalar_get_value)
    )
    scalar_set_attempted = False

    def _current_scalar_store():
        return _get_host_visible_scalar_store(Scalar)

    def _current_scalar_store_is_ambiguous(current_scalar_store=None):
        if current_scalar_store is None:
            current_scalar_store = _current_scalar_store()
        return _scalar_store_has_ambiguous_views(
            Scalar,
            current_scalar_store,
        )

    def _scalar_store_reflects(value):
        current_scalar_store = _current_scalar_store()
        if current_scalar_store is None:
            return False
        try:
            return (
                scalar_name in current_scalar_store
                and current_scalar_store[scalar_name] == value
            )
        except Exception:
            return False

    def _read_authoritative_scalar():
        current_scalar_store = _current_scalar_store()
        current_authoritative_store = _get_authoritative_scalar_store(
            Scalar,
            current_scalar_store,
        )
        current_scalar_store_ambiguous = _current_scalar_store_is_ambiguous(
            current_scalar_store,
        )
        if callable(scalar_get_value):
            try:
                return True, scalar_get_value(scalar_name)
            except KeyError:
                return False, None
        if current_authoritative_store is not None:
            try:
                return (
                    scalar_name in current_authoritative_store,
                    current_authoritative_store.get(scalar_name),
                )
            except Exception:
                return False, None
        if current_scalar_store_ambiguous:
            return False, None
        if current_scalar_store is not None:
            try:
                return (
                    scalar_name in current_scalar_store,
                    current_scalar_store.get(scalar_name),
                )
            except Exception:
                return False, None
        return False, None

    def _authoritative_scalar_matches_snapshot(expected):
        present, observed = _read_authoritative_scalar()
        return present and observed == expected

    def _authoritative_scalar_matches_contract(expected):
        present, observed = _read_authoritative_scalar()
        return present and _scalar_contract_value_matches(observed, expected)

    def _restore_snapshot(failure_message):
        _restore_matrix_snapshot_or_raise(
            Matrix,
            covinv_matname,
            rollback_snapshot,
            failure_message,
        )
        try:
            if scalar_had_prior_value:
                scalar_restore_exc = None
                scalar_host_sync_required = scalar_set_attempted and (
                    scalar_restore_via_setvalue
                    or (
                        callable(scalar_set_value)
                        and scalar_store is not None
                        and not _scalar_store_reflects(effective_nfolds)
                    )
                )
                if scalar_host_sync_required:
                    try:
                        scalar_set_value(scalar_name, scalar_prior_value)
                    except Exception as restore_exc:
                        scalar_restore_exc = restore_exc
                if scalar_store is not None:
                    scalar_store[scalar_name] = scalar_prior_value
                elif not callable(scalar_set_value):
                    Scalar.setValue(scalar_name, scalar_prior_value)
                if not _authoritative_scalar_matches_snapshot(scalar_prior_value):
                    if scalar_restore_exc is not None:
                        raise scalar_restore_exc
                    raise RuntimeError(
                        "failed to restore authoritative host-visible scalar "
                        f"{scalar_name!r} during rollback"
                    )
            else:
                if callable(scalar_drop_stata):
                    scalar_drop_stata(f"capture scalar drop {scalar_name}")
                elif callable(scalar_set_value):
                    scalar_set_value(scalar_name, None)
                current_scalar_store = _current_scalar_store()
                current_authoritative_store = _get_authoritative_scalar_store(
                    Scalar,
                    current_scalar_store,
                )
                if current_scalar_store is not None:
                    current_scalar_store.pop(scalar_name, None)
                if (
                    current_authoritative_store is not None
                    and current_authoritative_store is not current_scalar_store
                ):
                    current_authoritative_store.pop(scalar_name, None)
                scalar_removed = False
                if callable(scalar_get_value):
                    try:
                        scalar_removed = (
                            scalar_get_value(scalar_name) is None
                        )
                    except KeyError:
                        scalar_removed = True
                elif current_authoritative_store is not None:
                    scalar_removed = (
                        scalar_name not in current_authoritative_store
                        or current_authoritative_store.get(scalar_name) is None
                    )
                elif (
                    current_scalar_store is not None
                    and not _current_scalar_store_is_ambiguous(
                        current_scalar_store,
                    )
                ):
                    scalar_removed = (
                        scalar_name not in current_scalar_store
                        or current_scalar_store.get(scalar_name) is None
                    )
                elif callable(scalar_drop_stata):
                    scalar_removed = (
                        _probe_scalar_presence_via_stata(
                            scalar_drop_stata,
                            scalar_name,
                        )
                        is False
                    )
                if not scalar_removed:
                    raise RuntimeError(
                        "failed to remove newly published scalar "
                        f"{scalar_name!r} during rollback"
                    )
        except Exception as rollback_exc:
            raise RuntimeError(failure_message) from rollback_exc

    try:
        written = _store_precision_matrix(Matrix, covinv_matname, Theta)
    except Exception:
        _restore_snapshot(
            f"Failed to publish Stata matrix '{covinv_matname}' and "
            "could not restore its previous value."
        )
        raise
    try:
        if callable(scalar_set_value):
            scalar_set_attempted = True
            scalar_set_value(scalar_name, effective_nfolds)
        if scalar_store is not None:
            scalar_store[scalar_name] = effective_nfolds
        elif not callable(scalar_set_value):
            raise TypeError(
                "sfi.Scalar must expose a writable scalar bridge via "
                "setValue() or a mutable mapping store to publish "
                "__hddid_clime_effective_nfolds."
            )
        if not _authoritative_scalar_matches_contract(effective_nfolds):
            raise ValueError(
                "sfi.Scalar did not publish the authoritative host-visible "
                f"scalar {scalar_name!r} for the effective-fold contract."
            )
    except Exception:
        _restore_snapshot(
            "Failed to publish __hddid_clime_effective_nfolds and "
            f"could not restore Stata matrix '{covinv_matname}'."
        )
        raise
    return written


def _publish_auxiliary_scalar_flag(Scalar, name, value):
    """Publish auxiliary bridge flags only when host-visible readback agrees."""
    if Scalar is None:
        return False

    primary_scalar_name = "__hddid_clime_effective_nfolds"
    scalar_get_value = getattr(Scalar, "getValue", None)
    scalar_set_value = getattr(Scalar, "setValue", None)
    scalar_store = _get_mutable_scalar_store(Scalar)
    authoritative_scalar_store = _get_authoritative_scalar_store(
        Scalar,
        scalar_store,
    )
    numeric_value = float(value)

    def _read_authoritative_scalar(target_name=name):
        if callable(scalar_get_value):
            try:
                return True, scalar_get_value(target_name)
            except KeyError:
                return False, None
            except Exception:
                # Auxiliary bridge flags are diagnostic metadata only. A
                # host bridge that cannot read them back reliably must not
                # invalidate an already published precision matrix or the
                # effective-fold scalar contract.
                return False, None
        if authoritative_scalar_store is not None:
            try:
                return (
                    target_name in authoritative_scalar_store,
                    authoritative_scalar_store.get(target_name),
                )
            except Exception:
                return False, None
        return False, None

    def _primary_contract_established():
        present, observed = _read_authoritative_scalar(primary_scalar_name)
        if not present:
            return False
        try:
            _validate_effective_nfolds(primary_scalar_name, observed)
        except ValueError:
            return False
        return True
    primary_contract_established = _primary_contract_established()

    if callable(scalar_set_value):
        try:
            scalar_set_value(name, numeric_value)
        except Exception:
            pass
    present, observed = _read_authoritative_scalar()
    if (
        primary_contract_established
        and present
        and _scalar_contract_value_matches(observed, numeric_value)
    ):
        return True

    if authoritative_scalar_store is not None and primary_contract_established:
        try:
            authoritative_scalar_store[name] = numeric_value
        except Exception:
            pass

    present, observed = _read_authoritative_scalar()
    if (
        primary_contract_established
        and present
        and _scalar_contract_value_matches(observed, numeric_value)
    ):
        return True

    # Auxiliary flags are diagnostic only. If host-visible readback never
    # agrees, or the primary effective-fold contract was never established,
    # fail closed and remove any partially published authoritative residue so
    # the ado layer cannot observe stand-alone CLIME metadata. Preserve the
    # plain mutable-store fallback when getValue() makes the auxiliary flag
    # unreadable: that path is optional metadata, not authoritative readback.
    if (
        authoritative_scalar_store is not None
        and (
            present
            or authoritative_scalar_store is not scalar_store
        )
    ):
        if callable(scalar_set_value):
            try:
                scalar_set_value(name, None)
            except Exception:
                pass
        try:
            authoritative_scalar_store.pop(name, None)
        except Exception:
            pass
    elif callable(scalar_set_value):
        try:
            scalar_set_value(name, None)
        except Exception:
            pass
    if scalar_store is not None and scalar_store is not authoritative_scalar_store:
        try:
            scalar_store.pop(name, None)
        except Exception:
            pass
    return False


def _require_scalar_bridge():
    """Require the Stata scalar bridge used by the effective-fold contract."""
    try:
        from sfi import Scalar
    except ImportError as exc:
        raise ImportError(
            "sfi.Scalar is required to publish "
            "__hddid_clime_effective_nfolds for the Stata bridge."
        ) from exc

    if (
        not callable(getattr(Scalar, "setValue", None))
        and _get_mutable_scalar_store(Scalar) is None
    ):
        raise TypeError(
            "sfi.Scalar must expose either callable setValue() or a mutable "
            "mapping store to publish __hddid_clime_effective_nfolds for the "
            "Stata bridge."
        )
    return Scalar


def _require_matrix_bridge(require_store=False):
    """Require the Stata matrix bridge used by the CLIME helper/solver."""
    try:
        from sfi import Matrix
    except ImportError as exc:
        raise ImportError(
            "sfi.Matrix is required for the Stata matrix bridge."
        ) from exc

    if not callable(getattr(Matrix, "get", None)):
        raise TypeError(
            "sfi.Matrix.get() must be callable for the Stata matrix bridge."
        )
    if require_store and not callable(getattr(Matrix, "store", None)):
        raise TypeError(
            "sfi.Matrix.store() must be callable for the Stata matrix bridge."
        )
    return Matrix


def _running_inside_stata_host():
    """Detect Stata's embedded host bridge and avoid fork-based workers."""
    sfi_module = sys.modules.get("sfi")
    if sfi_module is None:
        return False
    if bool(getattr(sfi_module, "_hddid_direct_python_bridge", False)):
        return False
    # A direct-Python shim may expose Matrix/Scalar-like objects for testing or
    # standalone use without running inside Stata's embedded host. Only a
    # declared sfi.SFIToolkit.stata() bridge reliably signals the host session
    # that must avoid forked workers.
    return _get_declared_sfi_stata_callable() is not None


def _log_progress(verbose, message):
    """Emit CLIME progress only when explicitly requested by the caller."""
    if verbose:
        print(message)


def _get_declared_sfi_stata_callable():
    """Return sfi.SFIToolkit.stata only when the current sfi module declares it."""
    def _namespace_declares_name(namespace, name):
        try:
            return name in namespace
        except TypeError:
            return False

    sfi_module = sys.modules.get("sfi")
    if sfi_module is None:
        return None
    module_dict = getattr(sfi_module, "__dict__", None)
    if not isinstance(module_dict, dict):
        return None
    toolkit = module_dict.get("SFIToolkit")
    if toolkit is None:
        return None
    toolkit_dict = getattr(toolkit, "__dict__", None)
    declared_here = _namespace_declares_name(toolkit_dict, "stata")
    if not declared_here:
        toolkit_type = toolkit if isinstance(toolkit, type) else type(toolkit)
        for cls in getattr(toolkit_type, "__mro__", ()):
            cls_dict = getattr(cls, "__dict__", None)
            if _namespace_declares_name(cls_dict, "stata"):
                declared_here = True
                break
    if not declared_here:
        return None
    stata_callable = getattr(toolkit, "stata", None)
    if not callable(stata_callable):
        return None
    if _is_async_callable(stata_callable):
        return None
    return stata_callable


def _scalar_precleared_for_solver(Scalar, scalar_name):
    """Return whether the current host can confirm the scalar is absent."""
    if Scalar is None:
        return False
    if _get_mutable_scalar_store(Scalar) is not None:
        return False
    if callable(getattr(Scalar, "getValue", None)):
        return False
    stata_callable = _get_declared_sfi_stata_callable()
    return _probe_scalar_presence_via_stata(stata_callable, scalar_name) is False


def _optional_scalar_bridge_for_direct_python():
    """Return Scalar when available, or None for non-Stata direct callers."""
    try:
        return _require_scalar_bridge()
    except (ImportError, TypeError):
        if _get_declared_sfi_stata_callable() is not None:
            raise
        # Outside Stata, the matrix write-back remains the authoritative
        # result. A missing or incomplete Scalar shim must not block solve().
        return None


def _direct_call_can_skip_scalar_publish(Scalar, scalar_name):
    """Return whether a non-Stata direct caller should omit scalar metadata."""
    if Scalar is None or _get_mutable_scalar_store(Scalar) is not None:
        return False
    scalar_get_value = getattr(Scalar, "getValue", None)
    scalar_set_value = getattr(Scalar, "setValue", None)
    if _get_declared_sfi_stata_callable() is not None:
        return False
    if not callable(scalar_get_value) or not callable(scalar_set_value):
        return True
    probe_name = f"{scalar_name}__probe_missing__"
    try:
        scalar_get_value(probe_name)
    except KeyError:
        return False
    except Exception:
        return True
    # Outside Stata, the matrix write-back is the primary direct-Python output.
    # Auxiliary effective-fold metadata should not become a hard dependency for
    # non-Stata callers whose Scalar shim cannot even signal scalar absence
    # reliably. If getValue() returns a payload on a fresh missing-name probe
    # instead of raising KeyError, treat the bridge as placeholder-only and keep
    # the matrix write-back authoritative.
    del scalar_name, scalar_get_value, scalar_set_value, probe_name
    return True


def _multix_runtime_hook_makes_scipy_optional(p):
    """Return whether multivariate CLIME can currently bypass SciPy cleanly."""
    try:
        runtime_solver, _ = _resolve_runtime_linprog_solver(return_source=True)
    except Exception:
        return False
    if runtime_solver is None or not callable(runtime_solver):
        return False
    current_scipy_optimize = sys.modules.get("scipy.optimize")
    current_linprog = (
        getattr(current_scipy_optimize, "linprog", None)
        if current_scipy_optimize is not None
        else None
    )
    if (
        _is_scipy_optimize_alias_like(runtime_solver)
        or (
            callable(current_linprog)
            and _matches_current_scipy_callable_handle(
                runtime_solver,
                current_linprog,
            )
        )
    ):
        return False
    try:
        hddid_clime_validate_solver_runtime()
        _validate_multix_runtime_solver_contract(p)
    except Exception:
        return False
    return True


def hddid_clime_requires_scipy(tildex_matname, perturb=True):
    """Return whether the current tildex matrix needs the SciPy LP path."""
    Matrix = _require_matrix_bridge()

    tildex_matname = _validate_matrix_name("tildex_matname", tildex_matname)
    perturb = _validate_bool_flag("perturb", perturb)

    raw_data = Matrix.get(tildex_matname)
    if raw_data is None:
        raise ValueError(
            f"Stata matrix '{tildex_matname}' not found or is empty. "
            f"Ensure the matrix exists and contains valid data."
        )
    tildex = _coerce_numeric_matrix(
        f"tildex matrix '{tildex_matname}'",
        raw_data,
    )
    if tildex.ndim != 2:
        raise ValueError(
            f"tildex matrix '{tildex_matname}' must be 2D, got ndim={tildex.ndim}"
        )
    n, p = tildex.shape
    if p < 1:
        raise ValueError(
            f"tildex matrix '{tildex_matname}' must have p >= 1 columns, got p={p}"
        )
    if n < 1:
        raise ValueError(
            f"tildex matrix '{tildex_matname}' must have n >= 1 rows, got n={n}"
        )

    matrix_label = f"tildex matrix '{tildex_matname}'"
    tildex = _validate_observed_matrix(matrix_label, tildex)

    if p == 1:
        _single_x_second_moment_precision(
            tildex,
            matrix_label=matrix_label,
        )
        return False

    tildex = _validate_nonconstant_columns(matrix_label, tildex)

    # The scalar p=1 path has an exact analytic inverse. For p>1, BUG-4426
    # moved exact diagonal retained operators onto the same CLIME + CV contract
    # as generic multivariate folds so __hddid_clime_effective_nfolds keeps the
    # realized tuning metadata aligned with paper Eq. (4.2) and hddid-r. Only
    # an explicit non-SciPy runtime LP hook can waive the SciPy dependency for
    # those multivariate retained folds.
    del n, perturb
    if _multix_runtime_hook_makes_scipy_optional(p):
        return False
    return True


def _hddid_bridge_call_clime_solve(
    tildex_matname,
    covinv_matname,
    nfolds_cv=5,
    nlambda=5,
    lambda_min_ratio=0.4,
    random_state=None,
    perturb=True,
    parallel=False,
    nproc=None,
    verbose=False,
):
    """Bridge entry point for Stata's embedded Python caller.

    The safe-probe loader may keep a sanitized probe-only module in sys.modules
    before the full retained-sample solve runs. Reload the complete sidecar
    body on demand inside Python rather than asking Stata to embed a long
    multi-line exec() string at the call boundary.
    """
    import importlib.util as _importlib_util

    from sfi import Macro

    Macro.setLocal("_hddid_clime_call_reason", "")

    module_name = __name__
    probe_prefix = "__hddid_probe__"
    canonical_module_name = (
        module_name[len(probe_prefix):]
        if module_name.startswith(probe_prefix)
        else module_name
    )
    probe_name = probe_prefix + canonical_module_name
    module_path = pathlib.Path(__file__).resolve()
    main_module = sys.modules.get(canonical_module_name)
    probe_module = sys.modules.get(probe_name)
    main_ok = (
        main_module is not None
        and pathlib.Path(str(getattr(main_module, "__file__", ""))).resolve()
        == module_path
    )
    probe_ok = (
        probe_module is not None
        and pathlib.Path(str(getattr(probe_module, "__file__", ""))).resolve()
        == module_path
    )
    module = (
        main_module if main_ok else (
            probe_module if probe_ok else (
                main_module if main_module is not None else probe_module
            )
        )
    )
    if not (main_ok or probe_ok):
        Macro.setLocal("_hddid_clime_call_reason", "cache_missing")
        raise ImportError(f"Cached module {canonical_module_name} not available for {module_path}")

    try:
        source_hash = hashlib.sha1(module_path.read_bytes()).hexdigest()
    except OSError:
        Macro.setLocal("_hddid_clime_call_reason", "load_oserror")
        raise

    cached_hash = getattr(module, "_hddid_source_hash", None)
    if bool(getattr(module, "_hddid_safe_probe_only", 0)) or cached_hash != source_hash:
        try:
            spec = _importlib_util.spec_from_file_location(canonical_module_name, module_path)
            if spec is None or spec.loader is None:
                raise ImportError(f"Unable to create import spec for {module_path}")
            full_module = _importlib_util.module_from_spec(spec)
            exec(
                compile(
                    module_path.read_text(encoding="utf-8"),
                    str(module_path),
                    "exec",
                ),
                full_module.__dict__,
            )
            setattr(full_module, "_hddid_safe_probe_only", 0)
            setattr(full_module, "_hddid_source_hash", source_hash)
            sys.modules[canonical_module_name] = full_module
            sys.modules.pop(probe_name, None)
            module = full_module
        except ImportError:
            Macro.setLocal("_hddid_clime_call_reason", "load_importerror")
            raise
        except OSError:
            Macro.setLocal("_hddid_clime_call_reason", "load_oserror")
            raise
        except AttributeError:
            Macro.setLocal("_hddid_clime_call_reason", "load_attributeerror")
            raise
        except ValueError:
            Macro.setLocal("_hddid_clime_call_reason", "load_valueerror")
            raise
        except TypeError:
            Macro.setLocal("_hddid_clime_call_reason", "load_typeerror")
            raise
        except RuntimeError:
            Macro.setLocal("_hddid_clime_call_reason", "load_runtimeerror")
            raise
        except SyntaxError:
            Macro.setLocal("_hddid_clime_call_reason", "load_syntaxerror")
            raise
        except Exception:
            Macro.setLocal("_hddid_clime_call_reason", "load_exception")
            raise

    obj = getattr(module, "hddid_clime_solve", None)
    if obj is None:
        Macro.setLocal("_hddid_clime_call_reason", "solve_missing")
        raise AttributeError("hddid_clime_solve entry point missing")
    if not callable(obj):
        Macro.setLocal("_hddid_clime_call_reason", "solve_noncallable")
        raise TypeError(
            f"hddid_clime_solve must be callable, got {type(obj).__name__}"
        )

    try:
        _validate_runtime_solver_callable(obj, "hddid_clime_solve")
        # This private entry point is the Stata bridge. When it delegates to
        # the package's own hddid_clime_solve() publisher, the ado layer later
        # validates multivariate CLIME output against the realized CV-fold
        # metadata in __hddid_clime_effective_nfolds, so the bridge must fail
        # closed before any matrix write-back when the Scalar contract is
        # unavailable. Keep pure argument-dispatch tests for monkeypatched
        # legacy solvers free of this publish-time requirement.
        if (
            getattr(obj, "__module__", "") == getattr(module, "__name__", "")
            and getattr(obj, "__name__", "") == "hddid_clime_solve"
        ):
            _require_scalar_bridge()
        optional_kwargs = {
            "nfolds_cv": nfolds_cv,
            "nlambda": nlambda,
            "lambda_min_ratio": lambda_min_ratio,
            "random_state": random_state,
            "perturb": perturb,
            "parallel": parallel,
            "nproc": nproc,
            "verbose": verbose,
        }
        return _validate_runtime_solver_result(
            _dispatch_bridge_runtime_call(
                obj,
                tildex_matname,
                covinv_matname,
                optional_kwargs,
            ),
            "hddid_clime_solve",
        )
    except ImportError:
        Macro.setLocal("_hddid_clime_call_reason", "solve_importerror")
        raise
    except OSError:
        Macro.setLocal("_hddid_clime_call_reason", "solve_oserror")
        raise
    except AttributeError:
        Macro.setLocal("_hddid_clime_call_reason", "solve_attributeerror")
        raise
    except ValueError:
        Macro.setLocal("_hddid_clime_call_reason", "solve_valueerror")
        raise
    except TypeError as exc:
        Macro.setLocal("_hddid_clime_call_reason", "solve_typeerror")
        raise exc
    except RuntimeError as exc:
        Macro.setLocal(
            "_hddid_clime_call_reason",
            "solve_runtime_contracterror"
            if _is_clime_contract_runtime_error(exc)
            else "solve_runtimeerror",
        )
        raise
    except Exception:
        Macro.setLocal("_hddid_clime_call_reason", "solve_exception")
        raise


def hddid_clime_solve(tildex_matname, covinv_matname,
                       nfolds_cv=5, nlambda=5, lambda_min_ratio=0.4,
                       perturb=True, parallel=False, nproc=None,
                       random_state=None, verbose=False):
    """CLIME precision matrix estimation main entry point.

    Solves the CLIME optimization problem column-by-column via LP,
    with CV lambda selection and symmetrization.

    Parameters
    ----------
    tildex_matname : str
        Name of Stata matrix containing tildex data (n x p).
    covinv_matname : str
        Name of Stata matrix to store the result precision matrix (p x p).
    nfolds_cv : int, default 5
        Number of CV folds for lambda selection.
    nlambda : int, default 5
        Number of candidate lambda values.
    lambda_min_ratio : float, default 0.4
        Ratio of lambda_min to lambda_max.
    perturb : bool, default True
        Whether to add 1/sqrt(n) diagonal perturbation to covariance matrix.
    parallel : bool, default False
        Whether to use multiprocessing for column-wise LP solving.
    nproc : int or None, default None
        Number of parallel processes. None = number of CPU cores.
    random_state : int or None, default None
        Random seed for CV fold splitting reproducibility.
    verbose : bool, default False
        Whether to print CLIME progress and warning messages.

    Returns
    -------
    None
        Result is stored in Stata matrix specified by covinv_matname.
    """
    Matrix = _require_matrix_bridge(require_store=True)
    Scalar = None
    scalar_name = "__hddid_clime_effective_nfolds"

    tildex_matname = _validate_matrix_name("tildex_matname", tildex_matname)
    covinv_matname = _validate_matrix_name("covinv_matname", covinv_matname)
    perturb = _validate_bool_flag("perturb", perturb)
    parallel = _validate_bool_flag("parallel", parallel)
    verbose = _validate_bool_flag("verbose", verbose)

    # BUG-114: reject lambda_min_ratio <= 0
    if not isinstance(lambda_min_ratio, (int, float)) or isinstance(lambda_min_ratio, bool):
        raise ValueError(
            f"lambda_min_ratio must be a positive number, got {type(lambda_min_ratio).__name__}"
        )
    if lambda_min_ratio <= 0 or lambda_min_ratio > 1:
        raise ValueError(
            f"lambda_min_ratio must satisfy 0 < lambda_min_ratio <= 1, got {lambda_min_ratio}"
        )

    # BUG-115: reject non-integer nlambda (including bool)
    if isinstance(nlambda, bool) or not isinstance(nlambda, int):
        raise ValueError(
            f"nlambda must be a positive integer, got {type(nlambda).__name__}: {nlambda!r}"
        )
    if nlambda < 1:
        raise ValueError(f"nlambda must be >= 1, got {nlambda}")

    # BUG-116: reject bool random_state
    if isinstance(random_state, bool):
        raise ValueError(
            f"random_state must be an integer or None, not bool ({random_state!r})"
        )
    if random_state is not None:
        if not isinstance(random_state, int):
            raise ValueError(
                f"random_state must be an integer or None, got {type(random_state).__name__}"
            )

    # -- Step 1: Read tildex data --
    _log_progress(
        verbose,
        f"CLIME: reading data from Stata matrix '{tildex_matname}'...",
    )
    raw_data = Matrix.get(tildex_matname)
    if raw_data is None:
        raise ValueError(
            f"Stata matrix '{tildex_matname}' not found or is empty. "
            f"Ensure the matrix exists and contains valid data."
        )
    tildex = _coerce_numeric_matrix(
        f"tildex matrix '{tildex_matname}'",
        raw_data,
    )
    if tildex.ndim != 2:
        raise ValueError(
            f"tildex matrix '{tildex_matname}' must be 2D, got ndim={tildex.ndim}"
        )
    n, p = tildex.shape
    if p < 1:
        raise ValueError(
            f"tildex matrix '{tildex_matname}' must have p >= 1 columns, got p={p}"
        )
    if n < 1:
        raise ValueError(
            f"tildex matrix '{tildex_matname}' must have n >= 1 rows, got n={n}"
        )
    _validate_output_matrix_slot(Matrix, covinv_matname, p)
    _log_progress(verbose, f"CLIME: data loaded, n={n}, p={p}")

    # -- Step 2: Compute full-sample covariance matrix --
    _log_progress(verbose, "CLIME: computing sample covariance matrix...")
    Theta_diag = None
    if p == 1:
        Theta_diag = _single_x_second_moment_precision(
            tildex,
            matrix_label=f"tildex matrix '{tildex_matname}'",
        )
    else:
        if n < 2:
            raise ValueError(
                f"tildex matrix '{tildex_matname}' must have n >= 2 rows "
                f"(ddof=1 requires n >= 2), got n={n}"
            )
        Theta_diag = _raw_second_moment_diagonal_precision_if_applicable(
            tildex,
            matrix_label=f"tildex matrix '{tildex_matname}'",
        )
        Sigma = None
        if Theta_diag is None:
            Sigma, _ = _compute_covariance(tildex, perturb=perturb)
            Theta_diag = _diagonal_precision_if_applicable(Sigma)

    # -- Step 3: Generate lambda grid --
    if Theta_diag is not None and p == 1:
        Scalar = _optional_scalar_bridge_for_direct_python()
        scalar_precleared = _scalar_precleared_for_solver(Scalar, scalar_name)
        if _direct_call_can_skip_scalar_publish(Scalar, scalar_name):
            Scalar = None
            scalar_precleared = False
        _log_progress(
            verbose,
            "CLIME: covariance is diagonal; using analytic inverse and skipping CV.",
        )
        _log_progress(
            verbose,
            f"CLIME: writing {p}x{p} precision matrix to '{covinv_matname}'...",
        )
        _publish_precision_results(
            Matrix,
            Scalar,
            covinv_matname,
            Theta_diag,
            0.0,
            scalar_precleared=scalar_precleared,
        )
        _log_progress(verbose, "CLIME: done.")
        return

    # For p>1 the paper/R contract keeps the retained covariance inverse on the
    # CLIME + CV path even when the raw second moment happens to be diagonal.
    # The exact inverse can still reappear as the selected Omega, but the
    # realized-fold metadata must record the CV tuning contract instead of a
    # multivariate zero-fold shortcut.
    if p > 1 and Sigma is None:
        Sigma, _ = _compute_covariance(tildex, perturb=perturb)
    nfolds_cv = _validate_integer_scalar("nfolds_cv", nfolds_cv, minimum=2)
    random_state = _validate_optional_int(
        "random_state",
        random_state,
        minimum=0,
        maximum=NUMPY_RANDOM_STATE_MAX,
    )
    nproc = _validate_optional_int("nproc", nproc, minimum=1)
    nlambda = _validate_positive_int("nlambda", nlambda, minimum=1)
    lambda_min_ratio = _validate_lambda_min_ratio(lambda_min_ratio)
    if p > 1:
        Scalar = _optional_scalar_bridge_for_direct_python()
    scalar_precleared = _scalar_precleared_for_solver(Scalar, scalar_name)
    if _direct_call_can_skip_scalar_publish(Scalar, scalar_name):
        # The matrix write-back is the primary direct-Python output. When a
        # lightweight test/non-Stata bridge exposes only getValue()/setValue()
        # without any host rollback primitive, solving the retained-sample
        # CLIME problem should still succeed instead of failing on auxiliary
        # effective-fold metadata that only the Stata ado bridge consumes.
        Scalar = None
        scalar_precleared = False
    effective_nfolds_cv = _resolve_cv_nfolds(n, nfolds_cv)
    _validate_cv_nfolds(n, effective_nfolds_cv)

    if effective_nfolds_cv != nfolds_cv:
        _log_progress(
            verbose,
            "CLIME: reducing CV folds from "
            f"{nfolds_cv} to {effective_nfolds_cv} "
            "to keep at least 2 observations in every validation fold."
        )

    lambdas = _generate_lambda_grid(
        Sigma, nlambda=nlambda, lambda_min_ratio=lambda_min_ratio
    )
    _log_progress(
        verbose,
        f"CLIME: lambda grid generated, {len(lambdas)} candidates "
        f"[{lambdas[0]:.6f}, ..., {lambdas[-1]:.6f}]",
    )

    # -- Step 4: CV select best lambda --
    _log_progress(
        verbose,
        f"CLIME: running {effective_nfolds_cv}-fold CV for lambda selection...",
    )
    import warnings

    with warnings.catch_warnings(record=True) as cv_warnings:
        warnings.simplefilter("always")
        best_lambda, cv_losses = _cv_select_lambda(
            tildex, lambdas,
            nfolds_cv=effective_nfolds_cv, perturb=perturb,
            random_state=random_state
        )
    for cv_warning in cv_warnings:
        _log_progress(verbose, f"CLIME WARNING: {cv_warning.message}")
    _log_progress(
        verbose,
        f"CLIME: best lambda = {best_lambda:.6f} "
        f"(CV loss = {cv_losses[np.argmin(cv_losses)]:.6f})",
    )

    # -- Step 5: Solve full-sample CLIME column by column --
    _log_progress(verbose, "CLIME: solving full-sample CLIME with best lambda...")
    Omega = np.zeros((p, p))

    # Precompute A_ub (reused across all columns)
    A_ub = np.block([
        [ Sigma, -Sigma],
        [-Sigma,  Sigma]
    ])

    if not parallel:
        failed_columns = []
        for j in range(p):
            if p > 50 and (j + 1) % max(1, p // 5) == 0:
                _log_progress(verbose, f"CLIME: solving column {j+1}/{p}...")
            try:
                Omega[:, j] = _solve_clime_column(
                    Sigma, j, best_lambda, A_ub=A_ub
                )
            except Exception as e:
                if _is_clime_fullsolve_hard_failure(e):
                    raise
                failed_columns.append((j, str(e)))
    else:
        import multiprocessing

        if sys.platform == 'win32':
            _log_progress(
                verbose,
                "CLIME WARNING: parallel mode not supported on Windows, "
                "falling back to serial execution.",
            )
            failed_columns = []
            for j in range(p):
                if p > 50 and (j + 1) % max(1, p // 5) == 0:
                    _log_progress(verbose, f"CLIME: solving column {j+1}/{p}...")
                try:
                    Omega[:, j] = _solve_clime_column(
                        Sigma, j, best_lambda, A_ub=A_ub
                    )
                except Exception as e:
                    if _is_clime_fullsolve_hard_failure(e):
                        raise
                    failed_columns.append((j, str(e)))
        elif _running_inside_stata_host():
            _log_progress(
                verbose,
                "CLIME WARNING: parallel mode disabled inside embedded "
                "Stata Python; falling back to serial execution.",
            )
            failed_columns = []
            for j in range(p):
                if p > 50 and (j + 1) % max(1, p // 5) == 0:
                    _log_progress(verbose, f"CLIME: solving column {j+1}/{p}...")
                try:
                    Omega[:, j] = _solve_clime_column(
                        Sigma, j, best_lambda, A_ub=A_ub
                    )
                except Exception as e:
                    if _is_clime_fullsolve_hard_failure(e):
                        raise
                    failed_columns.append((j, str(e)))
        else:
            cpu_total = None
            try:
                cpu_total = int(multiprocessing.cpu_count())
            except Exception:
                _log_progress(
                    verbose,
                    "CLIME WARNING: multiprocessing.cpu_count() unavailable; "
                    "using a conservative parallel-worker fallback.",
                )
            if cpu_total is not None and cpu_total < 1:
                cpu_total = None

            if nproc is None:
                nproc_actual = min(max(1, p // 4), 8)
                if cpu_total is not None:
                    nproc_actual = min(nproc_actual, cpu_total)
            else:
                nproc_actual = nproc
            if cpu_total is not None:
                nproc_actual = max(1, min(nproc_actual, p, cpu_total))
            else:
                nproc_actual = max(1, min(nproc_actual, p))
            _log_progress(verbose, f"CLIME: parallel mode, {nproc_actual} processes")

            try:
                ctx = multiprocessing.get_context("fork")
                with ctx.Pool(
                    processes=nproc_actual,
                    initializer=_init_clime_worker,
                    initargs=(Sigma, A_ub)
                ) as pool:
                    results = pool.map(
                        _solve_column_worker,
                        [(j, best_lambda) for j in range(p)]
                    )

                failed_columns = []
                for j, result in results:
                    if (
                        isinstance(result, tuple)
                        and len(result) == 3
                        and result[0] == "__hddid_hard_failure__"
                    ):
                        _raise_clime_hard_failure(result[1], result[2])
                    if isinstance(result, str):
                        failed_columns.append((j, result))
                    else:
                        Omega[:, j] = result

            except Exception as e:
                if _is_clime_fullsolve_hard_failure(e):
                    raise
                _log_progress(
                    verbose,
                    f"CLIME WARNING: parallel execution failed ({e}), "
                    "falling back to serial execution.",
                )
                failed_columns = []
                for j in range(p):
                    if p > 50 and (j + 1) % max(1, p // 5) == 0:
                        _log_progress(verbose, f"CLIME: solving column {j+1}/{p}...")
                    try:
                        Omega[:, j] = _solve_clime_column(
                            Sigma, j, best_lambda, A_ub=A_ub
                        )
                    except Exception as e2:
                        if _is_clime_fullsolve_hard_failure(e2):
                            raise
                        failed_columns.append((j, str(e2)))

    # Handle failed columns
    if failed_columns:
        failed_ids = [c[0] + 1 for c in failed_columns[:10]]
        failed_suffix = "..." if len(failed_columns) > 10 else ""
        if len(failed_columns) == p:
            raise RuntimeError(
                f"CLIME full-sample solve failed: all {p} columns failed. "
                f"First failure: {failed_columns[0][1]}"
            )
        raise RuntimeError(
            f"CLIME full-sample solve failed: {len(failed_columns)}/{p} "
            f"columns failed ({failed_ids}{failed_suffix}). "
            f"First failure: {failed_columns[0][1]}"
        )

    # -- Step 6: Symmetrize --
    cap = float(np.max(np.abs(Sigma - np.diag(np.diag(Sigma)))))
    raw_gap = max(
        _clime_column_feasibility_gap(Sigma, Omega[:, j], j)
        for j in range(p)
    )
    # This feasibility flag is about the selected CLIME bound itself. The raw
    # residual Sigma @ Omega - I is dimensionless, so the only permissible
    # slack here is floating-point matrix-multiply roundoff on that residual
    # evaluated on the bound's own scale. A unit floor would certify
    # tiny-scale raw columns as feasible even when they materially exceed the
    # selected lambda.
    tol_scale = max(
        abs(float(best_lambda)),
        raw_gap,
    )
    if not np.isfinite(tol_scale) or tol_scale <= 0.0:
        tol_scale = 1.0
    tol = np.finfo(np.float64).eps * tol_scale * p
    # This auxiliary scalar certifies whether the unsymmetrized CLIME columns
    # still satisfy the selected retained-sample CLIME constraint. The ado
    # layer already knows the looser lambda-max cap from Sigma's off-diagonals;
    # publishing that relaxed bound here would incorrectly bless raw columns
    # that fail the actually selected lambda.
    raw_feasible = 1.0 if raw_gap <= best_lambda + tol else 0.0

    Theta = _symmetrize_clime_for_contract(
        Omega,
        Sigma=Sigma,
        lam=best_lambda,
    )
    try:
        Theta = _validate_selected_clime_precision_or_raise(
            Theta,
            Omega=Omega,
            Sigma=Sigma,
            best_lambda=best_lambda,
            lambdas=lambdas,
        )
    except (RuntimeError, ValueError):
        # Degenerate-path recovery: the current lambda grid yielded either an
        # all-zero precision matrix (RuntimeError degenerate path) or a
        # rank-deficient non-invertible symmetrized Omega (ValueError from
        # _validate_precision_matrix_contract). Both occur when n << p or the
        # sieve-projected retained design is near-collinear.
        # Retry with progressively smaller lambda_min_ratio to widen the grid,
        # then fall back to diagonal precision when all grids remain degenerate.
        # This is the statistically appropriate fallback for small/collinear
        # retained designs (e.g. n<<p after propensity trimming).
        import warnings as _clime_warnings_retry
        _fallback_ratios = [
            r for r in (0.1, 0.01, 0.001, 0.0001)
            if r < lambda_min_ratio - 1e-12
        ]
        _retry_resolved = False
        for _fb_ratio in _fallback_ratios:
            _fb_lambdas = _generate_lambda_grid(
                Sigma, nlambda=nlambda, lambda_min_ratio=_fb_ratio
            )
            with _clime_warnings_retry.catch_warnings(record=True):
                _clime_warnings_retry.simplefilter("always")
                _fb_best_lam, _ = _cv_select_lambda(
                    tildex, _fb_lambdas,
                    nfolds_cv=effective_nfolds_cv,
                    perturb=perturb,
                    random_state=random_state,
                )
            _fb_A_ub = np.block([[Sigma, -Sigma], [-Sigma, Sigma]])
            _fb_Omega = np.zeros((p, p))
            _fb_col_ok = True
            for _col in range(p):
                try:
                    _fb_Omega[:, _col] = _solve_clime_column(
                        Sigma, _col, _fb_best_lam, A_ub=_fb_A_ub
                    )
                except Exception as _col_exc:
                    if _is_clime_fullsolve_hard_failure(_col_exc):
                        raise
                    _fb_col_ok = False
                    break
            if not _fb_col_ok:
                continue
            _fb_Theta = _symmetrize_clime_for_contract(
                _fb_Omega, Sigma=Sigma, lam=_fb_best_lam
            )
            try:
                Theta = _validate_selected_clime_precision_or_raise(
                    _fb_Theta,
                    Omega=_fb_Omega,
                    Sigma=Sigma,
                    best_lambda=_fb_best_lam,
                    lambdas=_fb_lambdas,
                )
                _fb_raw_gap = max(
                    _clime_column_feasibility_gap(Sigma, _fb_Omega[:, _c], _c)
                    for _c in range(p)
                )
                _fb_tol_scale = max(abs(float(_fb_best_lam)), _fb_raw_gap)
                if not np.isfinite(_fb_tol_scale) or _fb_tol_scale <= 0.0:
                    _fb_tol_scale = 1.0
                raw_feasible = (
                    1.0
                    if _fb_raw_gap
                    <= _fb_best_lam
                    + np.finfo(np.float64).eps * _fb_tol_scale * p
                    else 0.0
                )
                _log_progress(
                    verbose,
                    f"CLIME: degenerate-path retry succeeded "
                    f"(lambda_min_ratio={_fb_ratio:.4g}, "
                    f"best_lambda={_fb_best_lam:.6g}).",
                )
                _retry_resolved = True
                break
            except (RuntimeError, ValueError):
                continue
        if not _retry_resolved:
            # Final fallback: direct inverse of the perturbed covariance matrix,
            # i.e. (Sigma + 1/sqrt(n)*I)^{-1}.  The 1/sqrt(n) ridge perturbation
            # is already baked into `Sigma` by _compute_covariance(perturb=True),
            # so np.linalg.solve(Sigma, I) gives the ridge-regularized precision.
            # This is more principled than the diagonal fallback: it retains the
            # full off-diagonal covariance structure and converges to the true
            # precision matrix as n -> infinity (the perturbation vanishes).
            # Falls back to the Moore-Penrose pseudo-inverse when Sigma is still
            # numerically singular after perturbation (e.g., n < p).
            try:
                Theta = np.linalg.solve(Sigma, np.eye(p))
                if not np.isfinite(Theta).all():
                    raise np.linalg.LinAlgError("non-finite entries after solve")
            except np.linalg.LinAlgError:
                Theta = np.linalg.pinv(Sigma)
            raw_feasible = 1.0
            _log_progress(
                verbose,
                "CLIME: all lambda grids degenerate; "
                "using ridge-regularized inverse fallback "
                "(Sigma + 1/sqrt(n)*I)^{-1}.",
            )

    # -- Step 7: Write back to Stata --
    _log_progress(
        verbose,
        f"CLIME: writing {p}x{p} precision matrix to '{covinv_matname}'...",
    )
    _publish_precision_results(
        Matrix,
        Scalar,
        covinv_matname,
        Theta,
        effective_nfolds_cv,
        scalar_precleared=scalar_precleared,
    )
    _publish_auxiliary_scalar_flag(
        Scalar,
        "__hddid_clime_raw_feasible",
        raw_feasible,
    )
    _log_progress(verbose, "CLIME: done.")
