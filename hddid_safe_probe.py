from __future__ import annotations

import ast
import contextlib
import functools
import hashlib
import importlib.util
import inspect
import pathlib
import sys
import types

import numpy
from sfi import Macro

_PROBE_SAFE_DICT_NAMES = set()
_PROBE_SAFE_GETATTR_NAMES = set()
_PROBE_SAFE_SIGNATURELIKE_NAMES = set()
_PROBE_SAFE_SIGNATURE_CLASS_NAMES = set()
_PROBE_SAFE_SIMPLENAMESPACE_NAMES = set()


def _probe_callee_name(node):
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        base = _probe_callee_name(node.value)
        return None if base is None else base + "." + node.attr
    return None


def _probe_lambda_arg_names(node):
    arg_names = {
        arg.arg for arg in list(node.args.posonlyargs) + list(node.args.args)
    }
    arg_names.update(arg.arg for arg in node.args.kwonlyargs)
    if node.args.vararg is not None:
        arg_names.add(node.args.vararg.arg)
    if node.args.kwarg is not None:
        arg_names.add(node.args.kwarg.arg)
    return arg_names


def _probe_comp_target_names(node):
    if isinstance(node, ast.Name):
        return {node.id}
    if isinstance(node, (ast.Tuple, ast.List)):
        target_names = set()
        for elt in node.elts:
            elt_names = _probe_comp_target_names(elt)
            if elt_names is None:
                return None
            target_names.update(elt_names)
        return target_names
    return None


def _probe_expr_is_safe_dictlike(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
):
    if isinstance(node, ast.Name):
        return node.id in _PROBE_SAFE_DICT_NAMES
    if (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "copy"
        and len(node.args) == 0
        and len(node.keywords) == 0
    ):
        return _probe_expr_is_safe_dictlike(
            node.func.value,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    callee = _probe_callee_name(getattr(node, "func", None))
    return (
        (
            isinstance(node, ast.Dict)
            or callee == "dict"
            or callee == "dict.fromkeys"
        )
        and _probe_safe_expr(
            node,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    )


def _probe_expr_is_safe_signaturelike(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
):
    signaturelike_names = (
        _PROBE_SAFE_SIGNATURELIKE_NAMES
        or {
            "inspect.signature",
            "inspect.Signature",
            "inspect.Signature.from_callable",
        }
    )
    if not isinstance(node, ast.Call):
        return False
    callee = _probe_callee_name(node.func)
    if callee in signaturelike_names:
        return _probe_safe_expr(
            node,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if (
        isinstance(node.func, ast.Attribute)
        and node.func.attr == "replace"
        and _probe_expr_is_safe_signaturelike(
            node.func.value,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    ):
        return all(
            _probe_safe_expr(
                arg,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            for arg in node.args
        ) and all(
            kw.arg is not None
            and isinstance(kw.arg, str)
            and _probe_safe_expr(
                kw.value,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            for kw in node.keywords
        )
    return False


def _probe_register_safe_dict_targets(
    node,
    probe_import_roots=None,
    probe_safe_names=None,
    probe_safe_calls=None,
    probe_safe_ctor_names=None,
    probe_safe_binding_exprs=None,
):
    if (
        probe_import_roots is None
        or probe_safe_names is None
        or probe_safe_calls is None
        or probe_safe_ctor_names is None
    ):
        targets = node.targets if isinstance(node, ast.Assign) else [node.target]
        for target in targets:
            if isinstance(target, ast.Name):
                _PROBE_SAFE_DICT_NAMES.add(target.id)
        return

    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        if _probe_expr_is_safe_dictlike(
            value,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        ):
            _PROBE_SAFE_DICT_NAMES.add(target.id)
            if probe_safe_binding_exprs is not None:
                probe_safe_binding_exprs[target.id] = value


def _probe_safe_callback_expr(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
):
    """Allow eager callback builtins to invoke only known-pure callables."""
    if isinstance(node, ast.Name):
        # Callbacks passed to eager builtins (map/filter) must resolve to the
        # actual builtin/pure allowlist entry, not a sidecar-defined shadow.
        return (
            node.id in probe_safe_calls
            and node.id not in probe_safe_names
            and node.id not in probe_import_roots
        )
    if isinstance(node, ast.Attribute):
        return _probe_callee_name(node) in probe_safe_calls
    if isinstance(node, ast.Lambda):
        return _probe_safe_expr(
            node,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    return False


def _probe_safe_comprehension(
    generators,
    terminal_nodes,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
):
    comp_safe_names = set(probe_safe_names)
    for generator in generators:
        if generator.is_async:
            return False
        if not _probe_safe_expr(
            generator.iter,
            probe_import_roots,
            comp_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        ):
            return False
        target_names = _probe_comp_target_names(generator.target)
        if target_names is None:
            return False
        comp_safe_names |= target_names
        for if_node in generator.ifs:
            if not _probe_safe_expr(
                if_node,
                probe_import_roots,
                comp_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            ):
                return False
    return all(
        _probe_safe_expr(
            terminal_node,
            probe_import_roots,
            comp_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
        for terminal_node in terminal_nodes
    )


def _probe_safe_expr(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names=None,
):
    if probe_safe_ctor_names is None:
        probe_safe_ctor_names = set()
    if isinstance(node, ast.Constant):
        return True
    if isinstance(node, ast.Starred):
        return _probe_safe_expr(
            node.value,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if isinstance(node, ast.Name):
        return (
            node.id in probe_import_roots
            or node.id in probe_safe_names
            or node.id in probe_safe_calls
        )
    if isinstance(node, ast.Lambda):
        lambda_safe_names = probe_safe_names | _probe_lambda_arg_names(node)
        return (
            all(
                _probe_safe_expr(
                    default,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                for default in node.args.defaults
            )
            and all(
                default is None
                or _probe_safe_expr(
                    default,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                for default in node.args.kw_defaults
            )
            and _probe_safe_expr(
                node.body,
                probe_import_roots,
                lambda_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
        )
    if isinstance(node, ast.Attribute):
        return _probe_safe_expr(
            node.value,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if isinstance(node, ast.Slice):
        return all(
            part is None
            or _probe_safe_expr(
                part,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            for part in (node.lower, node.upper, node.step)
        )
    if isinstance(node, ast.Subscript):
        return _probe_safe_expr(
            node.value,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        ) and _probe_safe_expr(
            node.slice,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if isinstance(node, (ast.Tuple, ast.List, ast.Set)):
        return all(
            _probe_safe_expr(
                elt,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            for elt in node.elts
        )
    if isinstance(node, ast.Dict):
        for key, value in zip(node.keys, node.values):
            if not (
                (
                    key is None
                    or _probe_safe_expr(
                        key,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                )
                and _probe_safe_expr(
                    value,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
            ):
                return False
        return True
    if isinstance(node, (ast.ListComp, ast.SetComp, ast.GeneratorExp)):
        return _probe_safe_comprehension(
            node.generators,
            [node.elt],
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if isinstance(node, ast.DictComp):
        return _probe_safe_comprehension(
            node.generators,
            [node.key, node.value],
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if isinstance(node, ast.UnaryOp):
        return _probe_safe_expr(
            node.operand,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if isinstance(node, ast.BinOp):
        return _probe_safe_expr(
            node.left,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        ) and _probe_safe_expr(
            node.right,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
    if isinstance(node, ast.BoolOp):
        return all(
            _probe_safe_expr(
                value,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            for value in node.values
        )
    if isinstance(node, ast.Compare):
        return _probe_safe_expr(
            node.left,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        ) and all(
            _probe_safe_expr(
                comp,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            for comp in node.comparators
        )
    if isinstance(node, ast.IfExp):
        return (
            _probe_safe_expr(
                node.test,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            and _probe_safe_expr(
                node.body,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            and _probe_safe_expr(
                node.orelse,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
        )
    if isinstance(node, ast.Call):
        callee = _probe_callee_name(node.func)
        if callee == "dict.fromkeys":
            # Pure dict.fromkeys(...) constants are safe to keep in the probe
            # module: they evaluate eagerly without side effects and often feed
            # top-level flags that hddid_clime_requires_scipy() reads.
            return (
                1 <= len(node.args) <= 2
                and all(
                    _probe_safe_expr(
                        arg,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                    for arg in node.args
                )
                and all(
                    (kw.arg is None or isinstance(kw.arg, str))
                    and _probe_safe_expr(
                        kw.value,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                    for kw in node.keywords
                )
            )
        if isinstance(node.func, ast.Attribute):
            receiver = node.func.value
            if (
                node.func.attr in {"copy", "keys", "values", "items"}
                and len(node.args) == 0
                and len(node.keywords) == 0
                and _probe_expr_is_safe_dictlike(
                    receiver,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
            ):
                return True
            if (
                node.func.attr == "get"
                and 1 <= len(node.args) <= 2
                and len(node.keywords) == 0
                and _probe_expr_is_safe_dictlike(
                    receiver,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                and all(
                    _probe_safe_expr(
                        arg,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                    for arg in node.args
                )
            ):
                return True
            if (
                node.func.attr == "replace"
                and _probe_expr_is_safe_signaturelike(
                    receiver,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                and all(
                    _probe_safe_expr(
                        arg,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                    for arg in node.args
                )
                and all(
                    kw.arg is not None
                    and isinstance(kw.arg, str)
                    and _probe_safe_expr(
                        kw.value,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                    for kw in node.keywords
                )
            ):
                return True
        if callee == "map":
            return (
                len(node.args) >= 2
                and _probe_safe_callback_expr(
                    node.args[0],
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                and all(
                    _probe_safe_expr(
                        arg,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                    for arg in node.args[1:]
                )
                and all(
                    (kw.arg is None or isinstance(kw.arg, str))
                    and _probe_safe_expr(
                        kw.value,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                    for kw in node.keywords
                )
            )
        if callee == "filter":
            return (
                len(node.args) == 2
                and (
                    (
                        isinstance(node.args[0], ast.Constant)
                        and node.args[0].value is None
                    )
                    or _probe_safe_callback_expr(
                        node.args[0],
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    )
                )
                and _probe_safe_expr(
                    node.args[1],
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                and len(node.keywords) == 0
            )
        if callee == "sorted":
            if len(node.args) != 1:
                return False
            if not _probe_safe_expr(
                node.args[0],
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            ):
                return False
            key_seen = False
            reverse_seen = False
            for kw in node.keywords:
                if kw.arg is None:
                    return False
                if kw.arg == "key":
                    if key_seen:
                        return False
                    key_seen = True
                    if not (
                        (
                            isinstance(kw.value, ast.Constant)
                            and kw.value.value is None
                        )
                        or _probe_safe_callback_expr(
                            kw.value,
                            probe_import_roots,
                            probe_safe_names,
                            probe_safe_calls,
                            probe_safe_ctor_names,
                        )
                    ):
                        return False
                    continue
                if kw.arg == "reverse":
                    if reverse_seen:
                        return False
                    reverse_seen = True
                    if not _probe_safe_expr(
                        kw.value,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    ):
                        return False
                    continue
                return False
            return True
        return (
            (
                callee in probe_safe_calls
                or (
                    callee in probe_safe_ctor_names
                    and len(node.args) == 0
                    and len(node.keywords) == 0
                )
            )
            and all(
                _probe_safe_expr(
                    arg,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                for arg in node.args
            )
            and all(
                (kw.arg is None or isinstance(kw.arg, str))
                and _probe_safe_expr(
                    kw.value,
                    probe_import_roots,
                    probe_safe_names,
                    probe_safe_calls,
                    probe_safe_ctor_names,
                )
                for kw in node.keywords
            )
        )
    return False


def _probe_targets_ok(node):
    if isinstance(node, ast.Assign):
        targets = node.targets
    elif isinstance(node, ast.AnnAssign):
        targets = [node.target]
    else:
        return False

    def target_ok(target):
        if isinstance(target, ast.Name):
            return True
        if isinstance(target, ast.Starred):
            return target_ok(target.value)
        if isinstance(target, (ast.Tuple, ast.List)):
            if sum(isinstance(elt, ast.Starred) for elt in target.elts) > 1:
                return False
            return all(target_ok(elt) for elt in target.elts)
        return False

    return all(target_ok(target) for target in targets)


def _probe_register_targets(node, probe_safe_names):
    targets = node.targets if isinstance(node, ast.Assign) else [node.target]

    def add(target):
        if isinstance(target, ast.Name):
            probe_safe_names.add(target.id)
        elif isinstance(target, ast.Starred):
            add(target.value)
        elif isinstance(target, (ast.Tuple, ast.List)):
            for elt in target.elts:
                add(elt)

    for target in targets:
        add(target)


def _probe_expand_destructurable_value(
    value,
    probe_safe_binding_exprs=None,
    seen=None,
):
    if seen is None:
        seen = set()
    if probe_safe_binding_exprs is not None:
        while isinstance(value, ast.Name) and value.id not in seen:
            bound_value = probe_safe_binding_exprs.get(value.id)
            if bound_value is None:
                break
            seen.add(value.id)
            value = bound_value
    if not isinstance(value, (ast.Tuple, ast.List)):
        return value

    expanded_elts = []
    changed = False
    for elt in value.elts:
        if isinstance(elt, ast.Starred):
            expanded = _probe_expand_destructurable_value(
                elt.value,
                probe_safe_binding_exprs,
                seen=set(seen),
            )
            if not isinstance(expanded, (ast.Tuple, ast.List)):
                return value
            expanded_elts.extend(expanded.elts)
            changed = True
            continue
        expanded_elt = _probe_expand_destructurable_value(
            elt,
            probe_safe_binding_exprs,
            seen=set(seen),
        )
        expanded_elts.append(expanded_elt)
        changed = changed or expanded_elt is not elt

    if not changed:
        return value
    expanded_type = ast.List if isinstance(value, ast.List) else ast.Tuple
    return expanded_type(elts=expanded_elts, ctx=ast.Load())


def _probe_constant_subscript_index(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, int):
        return node.value
    if (
        isinstance(node, ast.UnaryOp)
        and isinstance(node.op, ast.USub)
        and isinstance(node.operand, ast.Constant)
        and isinstance(node.operand.value, int)
    ):
        return -node.operand.value
    return None


def _probe_constant_mapping_key(node):
    if isinstance(node, ast.Constant):
        value = node.value
        if isinstance(value, (str, int, float, bool, bytes, tuple)) or value is None:
            return value
    if (
        isinstance(node, ast.UnaryOp)
        and isinstance(node.op, ast.USub)
        and isinstance(node.operand, ast.Constant)
        and isinstance(node.operand.value, (int, float))
    ):
        return -node.operand.value
    return None


def _probe_dictlike_items(value):
    if isinstance(value, ast.Dict):
        return list(zip(value.keys, value.values))
    if (
        isinstance(value, ast.Call)
        and _probe_callee_name(value.func) == "dict"
        and len(value.args) == 0
        and all(keyword.arg is not None for keyword in value.keywords)
    ):
        return [
            (ast.Constant(keyword.arg), keyword.value)
            for keyword in value.keywords
        ]
    return None


def _probe_resolve_constant_subscript_value(
    value,
    probe_safe_binding_exprs=None,
    seen=None,
):
    mapping_key_node = None
    mapping_default_node = None
    base_expr = None
    if isinstance(value, ast.Subscript):
        base_expr = value.value
        mapping_key_node = value.slice
    elif (
        isinstance(value, ast.Call)
        and isinstance(value.func, ast.Attribute)
        and value.func.attr == "get"
        and 1 <= len(value.args) <= 2
        and len(value.keywords) == 0
    ):
        base_expr = value.func.value
        mapping_key_node = value.args[0]
        if len(value.args) == 2:
            mapping_default_node = value.args[1]
    else:
        return value

    base_value = _probe_resolve_destructurable_value(
        base_expr,
        probe_safe_binding_exprs,
        seen=set() if seen is None else set(seen),
    )
    dict_items = _probe_dictlike_items(base_value)
    if dict_items is not None:
        key = _probe_constant_mapping_key(mapping_key_node)
        if key is None:
            return value
        matched_value = None
        for dict_key, dict_value in dict_items:
            if _probe_constant_mapping_key(dict_key) == key:
                matched_value = dict_value
        if matched_value is None:
            if mapping_default_node is None:
                return value
            matched_value = mapping_default_node
        return _probe_resolve_destructurable_value(
            matched_value,
            probe_safe_binding_exprs,
            seen=set() if seen is None else set(seen),
        )
    if not isinstance(value, ast.Subscript):
        return value
    if not isinstance(base_value, (ast.Tuple, ast.List)):
        return value

    index = _probe_constant_subscript_index(value.slice)
    if index is not None:
        if -len(base_value.elts) <= index < len(base_value.elts):
            return _probe_resolve_destructurable_value(
                base_value.elts[index],
                probe_safe_binding_exprs,
                seen=set() if seen is None else set(seen),
            )
        return value

    if not isinstance(value.slice, ast.Slice):
        return value

    lower = _probe_constant_subscript_index(value.slice.lower) if value.slice.lower is not None else None
    upper = _probe_constant_subscript_index(value.slice.upper) if value.slice.upper is not None else None
    step = _probe_constant_subscript_index(value.slice.step) if value.slice.step is not None else None
    if step == 0:
        return value
    try:
        sliced_elts = base_value.elts[slice(lower, upper, step)]
    except Exception:
        return value
    sliced_type = ast.List if isinstance(base_value, ast.List) else ast.Tuple
    return sliced_type(elts=sliced_elts, ctx=ast.Load())


def _probe_resolve_destructurable_value(
    value,
    probe_safe_binding_exprs=None,
    seen=None,
):
    if probe_safe_binding_exprs is None:
        return value
    if seen is None:
        seen = set()
    while isinstance(value, ast.Name) and value.id not in seen:
        bound_value = probe_safe_binding_exprs.get(value.id)
        if bound_value is None:
            break
        seen.add(value.id)
        value = bound_value
    value = _probe_resolve_constant_subscript_value(
        value,
        probe_safe_binding_exprs,
        seen=seen,
    )
    if isinstance(value, (ast.Tuple, ast.List)):
        return _probe_expand_destructurable_value(
            value,
            probe_safe_binding_exprs,
            seen=seen,
        )
    return value


def _probe_resolve_safe_call(node, probe_safe_binding_exprs=None):
    if not isinstance(node, ast.Call):
        return node
    resolved_func = _probe_resolve_destructurable_value(
        node.func,
        probe_safe_binding_exprs,
    )
    if resolved_func is node.func:
        return node
    return ast.Call(func=resolved_func, args=node.args, keywords=node.keywords)


def _probe_register_destructurable_bindings(node, probe_safe_binding_exprs):
    if probe_safe_binding_exprs is None:
        return
    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        value = _probe_resolve_destructurable_value(
            value,
            probe_safe_binding_exprs,
        )
        if isinstance(value, (ast.Tuple, ast.List)):
            probe_safe_binding_exprs[target.id] = value


def _probe_iter_name_value_pairs(node, probe_safe_binding_exprs=None):
    targets = node.targets if isinstance(node, ast.Assign) else [node.target]
    value = _probe_resolve_destructurable_value(
        getattr(node, "value", None),
        probe_safe_binding_exprs,
    )

    def walk(target, current_value):
        if isinstance(target, ast.Name):
            yield target, current_value
            return
        if isinstance(target, ast.Starred):
            yield from walk(target.value, current_value)
            return
        current_value = _probe_resolve_destructurable_value(
            current_value,
            probe_safe_binding_exprs,
        )
        if not isinstance(target, (ast.Tuple, ast.List)):
            return
        if not isinstance(current_value, (ast.Tuple, ast.List)):
            return
        starred_positions = [
            idx for idx, elt in enumerate(target.elts) if isinstance(elt, ast.Starred)
        ]
        if len(starred_positions) > 1:
            return
        if not starred_positions:
            if len(target.elts) != len(current_value.elts):
                return
            for elt_target, elt_value in zip(target.elts, current_value.elts):
                yield from walk(elt_target, elt_value)
            return

        starred_idx = starred_positions[0]
        left_targets = target.elts[:starred_idx]
        right_targets = target.elts[starred_idx + 1 :]
        if len(current_value.elts) < len(left_targets) + len(right_targets):
            return

        for elt_target, elt_value in zip(left_targets, current_value.elts[: len(left_targets)]):
            yield from walk(elt_target, elt_value)

        middle_values = current_value.elts[
            len(left_targets) : len(current_value.elts) - len(right_targets)
        ]
        starred_value = (
            ast.List(elts=middle_values, ctx=ast.Load())
            if isinstance(current_value, ast.List)
            else ast.Tuple(elts=middle_values, ctx=ast.Load())
        )
        yield from walk(target.elts[starred_idx], starred_value)

        if right_targets:
            for elt_target, elt_value in zip(
                right_targets,
                current_value.elts[-len(right_targets) :],
            ):
                yield from walk(elt_target, elt_value)

    for target in targets:
        yield from walk(target, value)


def _probe_register_def(node, probe_safe_names):
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        probe_safe_names.add(node.name)


def _probe_sanitize_zero_arg_ctor_function(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
):
    if not isinstance(node, ast.FunctionDef):
        return False
    if node.decorator_list:
        return False
    if node.args.posonlyargs or node.args.args or node.args.kwonlyargs:
        return False
    if node.args.vararg is not None or node.args.kwarg is not None:
        return False
    if len(node.body) != 1 or not isinstance(node.body[0], ast.Return):
        return False
    return_value = node.body[0].value
    if return_value is None:
        return False
    return _probe_safe_expr(
        return_value,
        probe_import_roots,
        probe_safe_names,
        probe_safe_calls,
        probe_safe_ctor_names,
    )


def _probe_self_attribute_target_ok(node):
    return (
        isinstance(node, ast.Attribute)
        and isinstance(node.value, ast.Name)
        and node.value.id == "self"
    )


def _probe_sanitize_trivial_init_method(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
):
    if not isinstance(node, ast.FunctionDef) or node.name != "__init__":
        return False
    if node.decorator_list:
        return False
    if node.args.posonlyargs or node.args.kwonlyargs:
        return False
    if node.args.vararg is not None or node.args.kwarg is not None:
        return False
    if len(node.args.args) != 1 or node.args.args[0].arg != "self":
        return False
    if node.args.defaults or node.args.kw_defaults:
        return False

    for stmt in node.body:
        if (
            isinstance(stmt, ast.Expr)
            and isinstance(getattr(stmt, "value", None), ast.Constant)
            and isinstance(stmt.value.value, str)
        ):
            continue
        if isinstance(stmt, ast.Pass):
            continue
        if isinstance(stmt, ast.Return):
            if stmt.value is None:
                continue
            if isinstance(stmt.value, ast.Constant) and stmt.value.value is None:
                continue
            return False
        if isinstance(stmt, ast.Assign):
            if not stmt.targets or not all(
                _probe_self_attribute_target_ok(target) for target in stmt.targets
            ):
                return False
            if not _probe_safe_expr(
                stmt.value,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            ):
                return False
            continue
        if isinstance(stmt, ast.AnnAssign):
            if not _probe_self_attribute_target_ok(stmt.target):
                return False
            if stmt.value is not None and not _probe_safe_expr(
                stmt.value,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            ):
                return False
            continue
        return False
    return True


def _probe_strip_annotations(node):
    if isinstance(node, ast.AnnAssign):
        return ast.Assign(targets=[node.target], value=node.value)
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        all_args = list(node.args.posonlyargs) + list(node.args.args) + list(node.args.kwonlyargs)
        if getattr(node.args, "vararg", None) is not None:
            all_args.append(node.args.vararg)
        if getattr(node.args, "kwarg", None) is not None:
            all_args.append(node.args.kwarg)
        for arg in all_args:
            arg.annotation = None
        node.returns = None
    if isinstance(node, ast.ClassDef):
        for idx, child in enumerate(node.body):
            node.body[idx] = _probe_strip_annotations(child)
    return node


def _probe_class_bases_are_explicit_object_only(
    node,
    probe_safe_object_base_names=None,
    probe_safe_simplenamespace_names=None,
    probe_safe_binding_exprs=None,
):
    if probe_safe_object_base_names is None:
        probe_safe_object_base_names = {"object", "builtins.object"}
    if probe_safe_simplenamespace_names is None:
        probe_safe_simplenamespace_names = {"types.SimpleNamespace"}
    probe_safe_base_names = (
        probe_safe_object_base_names | probe_safe_simplenamespace_names
    )
    return all(
        _probe_safe_metadata_alias_name(
            base,
            probe_safe_base_names,
            probe_safe_binding_exprs,
        )
        in probe_safe_base_names
        for base in node.bases
    )


def _probe_register_assigned_object_base_aliases(
    node,
    probe_safe_object_base_names,
    probe_safe_binding_exprs=None,
):
    if probe_safe_object_base_names is None:
        probe_safe_object_base_names = {"object", "builtins.object"}
    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        base_name = _probe_safe_metadata_alias_name(
            value,
            probe_safe_object_base_names,
            probe_safe_binding_exprs,
        )
        if base_name in probe_safe_object_base_names:
            probe_safe_object_base_names.add(target.id)


def _probe_register_assigned_staticmethod_aliases(
    node,
    probe_safe_staticmethod_names,
    probe_safe_binding_exprs=None,
):
    if probe_safe_staticmethod_names is None:
        probe_safe_staticmethod_names = {
            "staticmethod",
            "builtins.staticmethod",
        }
    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        decorator_name = _probe_safe_metadata_alias_name(
            value,
            probe_safe_staticmethod_names,
            probe_safe_binding_exprs,
        )
        if decorator_name in probe_safe_staticmethod_names:
            probe_safe_staticmethod_names.add(target.id)


def _probe_safe_getattr_name(
    node,
    probe_safe_names,
    probe_safe_binding_exprs=None,
):
    safe_getattr_names = (
        _PROBE_SAFE_GETATTR_NAMES or {"getattr", "builtins.getattr"}
    )
    safe_base_names = {
        name.rsplit(".", 1)[0]
        for name in probe_safe_names
        if isinstance(name, str) and "." in name
    }
    node = _probe_resolve_destructurable_value(
        node,
        probe_safe_binding_exprs,
    )
    if not isinstance(node, ast.Call):
        return None
    if _probe_safe_alias_name(
        node.func,
        safe_getattr_names,
        probe_safe_binding_exprs,
    ) not in safe_getattr_names:
        return None
    if len(node.args) not in (2, 3) or node.keywords:
        return None
    if len(node.args) == 3:
        default_name = _probe_safe_metadata_alias_name(
            node.args[2],
            probe_safe_names,
            probe_safe_binding_exprs,
        )
        if default_name not in probe_safe_names:
            return None
    base_name = _probe_safe_alias_name(
        node.args[0],
        safe_base_names,
        probe_safe_binding_exprs,
    )
    attr_name = getattr(node.args[1], "value", None)
    if base_name is None or not isinstance(attr_name, str):
        return None
    candidate = f"{base_name}.{attr_name}"
    return candidate if candidate in probe_safe_names else None


def _probe_safe_alias_name(
    node,
    probe_safe_names,
    probe_safe_binding_exprs=None,
):
    node = _probe_resolve_destructurable_value(
        node,
        probe_safe_binding_exprs,
    )
    candidate = _probe_callee_name(node)
    if candidate in probe_safe_names:
        return candidate
    if isinstance(node, ast.BoolOp):
        operand_names = [
            _probe_safe_alias_name(
                value,
                probe_safe_names,
                probe_safe_binding_exprs,
            )
            for value in node.values
        ]
        if any(name not in probe_safe_names for name in operand_names):
            return None
        if isinstance(node.op, ast.Or):
            return operand_names[0]
        if isinstance(node.op, ast.And):
            return operand_names[-1]
        return None
    if isinstance(node, ast.IfExp):
        body_name = _probe_safe_alias_name(
            node.body,
            probe_safe_names,
            probe_safe_binding_exprs,
        )
        orelse_name = _probe_safe_alias_name(
            node.orelse,
            probe_safe_names,
            probe_safe_binding_exprs,
        )
        if body_name in probe_safe_names and orelse_name in probe_safe_names:
            return body_name
    return None


def _probe_safe_metadata_alias_name(
    node,
    probe_safe_names,
    probe_safe_binding_exprs=None,
):
    resolved = _probe_resolve_destructurable_value(
        node,
        probe_safe_binding_exprs,
    )
    candidate = _probe_safe_alias_name(
        resolved,
        probe_safe_names,
        probe_safe_binding_exprs,
    )
    if candidate in probe_safe_names:
        return candidate
    candidate = _probe_safe_getattr_name(
        resolved,
        probe_safe_names,
        probe_safe_binding_exprs,
    )
    if candidate in probe_safe_names:
        return candidate
    return None


def _probe_register_assigned_classmethod_aliases(
    node,
    probe_safe_classmethod_names,
    probe_safe_binding_exprs=None,
):
    if probe_safe_classmethod_names is None:
        probe_safe_classmethod_names = {
            "classmethod",
            "builtins.classmethod",
        }
    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        decorator_name = _probe_safe_metadata_alias_name(
            value,
            probe_safe_classmethod_names,
            probe_safe_binding_exprs,
        )
        if decorator_name in probe_safe_classmethod_names:
            probe_safe_classmethod_names.add(target.id)


def _probe_register_assigned_getattr_aliases(
    node,
    probe_safe_calls,
    probe_safe_getattr_names=None,
    probe_safe_binding_exprs=None,
):
    if probe_safe_getattr_names is None:
        probe_safe_getattr_names = _PROBE_SAFE_GETATTR_NAMES
    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        value_name = _probe_safe_metadata_alias_name(
            value,
            probe_safe_getattr_names,
            probe_safe_binding_exprs,
        )
        if value_name not in probe_safe_getattr_names:
            continue
        probe_safe_getattr_names.add(target.id)
        probe_safe_calls.add(target.id)


def _probe_register_assigned_signaturelike_aliases(
    node,
    probe_safe_calls,
    probe_safe_signaturelike_names=None,
    probe_safe_signature_class_names=None,
    probe_safe_binding_exprs=None,
):
    if probe_safe_signaturelike_names is None:
        probe_safe_signaturelike_names = _PROBE_SAFE_SIGNATURELIKE_NAMES
    if probe_safe_signature_class_names is None:
        probe_safe_signature_class_names = _PROBE_SAFE_SIGNATURE_CLASS_NAMES
    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        value_name = _probe_safe_metadata_alias_name(
            value,
            probe_safe_signaturelike_names,
            probe_safe_binding_exprs,
        )
        if value_name is None:
            continue
        if value_name in probe_safe_signature_class_names:
            probe_safe_signature_class_names.add(target.id)
            probe_safe_signaturelike_names.add(target.id)
            probe_safe_signaturelike_names.add(f"{target.id}.from_callable")
            probe_safe_calls.add(target.id)
            probe_safe_calls.add(f"{target.id}.from_callable")
        elif value_name in probe_safe_signaturelike_names:
            probe_safe_signaturelike_names.add(target.id)
            probe_safe_calls.add(target.id)


def _probe_register_assigned_simplenamespace_aliases(
    node,
    probe_safe_simplenamespace_names,
    probe_safe_calls,
    probe_safe_binding_exprs=None,
):
    if probe_safe_simplenamespace_names is None:
        probe_safe_simplenamespace_names = {"types.SimpleNamespace"}
    for target, value in _probe_iter_name_value_pairs(
        node,
        probe_safe_binding_exprs,
    ):
        value_name = _probe_safe_metadata_alias_name(
            value,
            probe_safe_simplenamespace_names,
            probe_safe_binding_exprs,
        )
        if value_name not in probe_safe_simplenamespace_names:
            continue
        probe_safe_simplenamespace_names.add(target.id)
        probe_safe_calls.add(target.id)


def _probe_sanitize_def(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
):
    if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        return False
    if not all(
        _probe_safe_expr(
            decorator,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
        for decorator in node.decorator_list
    ):
        return False
    if not all(
        _probe_safe_expr(
            default,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
        for default in node.args.defaults
    ):
        return False
    if not all(
        default is None
        or _probe_safe_expr(
            default,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        )
        for default in node.args.kw_defaults
    ):
        return False
    return True


def _probe_sanitize_static_helper_method(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
    probe_safe_staticmethod_names=None,
    probe_safe_classmethod_names=None,
    probe_safe_binding_exprs=None,
):
    if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        return False
    if probe_safe_staticmethod_names is None:
        probe_safe_staticmethod_names = {
            "staticmethod",
            "builtins.staticmethod",
        }
    if probe_safe_classmethod_names is None:
        probe_safe_classmethod_names = {
            "classmethod",
            "builtins.classmethod",
        }
    if node.name in {"__call__", "__init__"}:
        return False
    if len(node.decorator_list) != 1:
        return False
    decorator = _probe_resolve_destructurable_value(
        node.decorator_list[0],
        probe_safe_binding_exprs,
    )
    if _probe_safe_metadata_alias_name(
        decorator,
        probe_safe_staticmethod_names | probe_safe_classmethod_names
    ) not in (
        probe_safe_staticmethod_names | probe_safe_classmethod_names
    ):
        return False
    return _probe_sanitize_def(
        node,
        probe_import_roots,
        probe_safe_names,
        probe_safe_calls,
        probe_safe_ctor_names,
    )


def _probe_sanitize_class(
    node,
    probe_import_roots,
    probe_safe_names,
    probe_safe_calls,
    probe_safe_ctor_names,
    probe_safe_object_base_names=None,
    probe_safe_simplenamespace_names=None,
    probe_safe_staticmethod_names=None,
    probe_safe_classmethod_names=None,
    probe_safe_binding_exprs=None,
):
    if not isinstance(node, ast.ClassDef):
        return False
    if (
        node.decorator_list
        or node.keywords
        or not _probe_class_bases_are_explicit_object_only(
            node,
            probe_safe_object_base_names,
            probe_safe_simplenamespace_names,
            probe_safe_binding_exprs,
        )
    ):
        return False

    saw_call = False
    class_safe_names = set(probe_safe_names)
    class_safe_calls = set(probe_safe_calls)
    class_safe_binding_exprs = {}
    class_safe_getattr_names = set(
        _PROBE_SAFE_GETATTR_NAMES or {"getattr", "builtins.getattr"}
    )
    class_safe_signature_class_names = set(
        _PROBE_SAFE_SIGNATURE_CLASS_NAMES or {"inspect.Signature"}
    )
    class_safe_signaturelike_names = set(
        _PROBE_SAFE_SIGNATURELIKE_NAMES
        or {
            "inspect.signature",
            "inspect.Signature",
            "inspect.Signature.from_callable",
        }
    )
    class_safe_simplenamespace_names = set(
        probe_safe_simplenamespace_names or {"types.SimpleNamespace"}
    )
    class_safe_staticmethod_names = set(
        probe_safe_staticmethod_names
        or {"staticmethod", "builtins.staticmethod"}
    )
    class_safe_classmethod_names = set(
        probe_safe_classmethod_names or {"classmethod", "builtins.classmethod"}
    )
    for child in node.body:
        merged_class_binding_exprs = {
            **(probe_safe_binding_exprs or {}),
            **class_safe_binding_exprs,
        }
        if (
            isinstance(child, ast.Expr)
            and isinstance(getattr(child, "value", None), ast.Constant)
            and isinstance(child.value.value, str)
        ):
            continue
        if (
            isinstance(child, (ast.Assign, ast.AnnAssign))
            and _probe_targets_ok(child)
        ):
            targets = (
                child.targets if isinstance(child, ast.Assign) else [child.target]
            )
            if (
                len(targets) == 1
                and isinstance(targets[0], ast.Name)
                and targets[0].id == "__signature__"
                and _probe_safe_expr(
                    _probe_resolve_safe_call(
                        child.value,
                        merged_class_binding_exprs,
                    ),
                    probe_import_roots,
                    class_safe_names | {"__call__"},
                    class_safe_calls,
                    probe_safe_ctor_names,
                )
            ):
                continue
            if child.value is not None and _probe_safe_expr(
                child.value,
                probe_import_roots,
                class_safe_names,
                class_safe_calls,
                probe_safe_ctor_names,
            ):
                _probe_register_targets(child, class_safe_names)
                _probe_register_destructurable_bindings(
                    child,
                    class_safe_binding_exprs,
                )
                _probe_register_assigned_getattr_aliases(
                    child,
                    class_safe_calls,
                    class_safe_getattr_names,
                    class_safe_binding_exprs,
                )
                _probe_register_assigned_signaturelike_aliases(
                    child,
                    class_safe_calls,
                    class_safe_signaturelike_names,
                    class_safe_signature_class_names,
                    class_safe_binding_exprs,
                )
                _probe_register_assigned_simplenamespace_aliases(
                    child,
                    class_safe_simplenamespace_names,
                    class_safe_calls,
                    class_safe_binding_exprs,
                )
                _probe_register_assigned_staticmethod_aliases(
                    child,
                    class_safe_staticmethod_names,
                    class_safe_binding_exprs,
                )
                _probe_register_assigned_classmethod_aliases(
                    child,
                    class_safe_classmethod_names,
                    class_safe_binding_exprs,
                )
                continue
        if _probe_sanitize_trivial_init_method(
            child,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        ):
            continue
        if _probe_sanitize_static_helper_method(
            child,
            probe_import_roots,
            class_safe_names,
            class_safe_calls,
            probe_safe_ctor_names,
            class_safe_staticmethod_names,
            class_safe_classmethod_names,
            merged_class_binding_exprs,
        ):
            continue
        if not isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) or child.name != "__call__":
            return False
        if not _probe_sanitize_def(
            child,
            probe_import_roots,
            probe_safe_names,
            probe_safe_calls,
            probe_safe_ctor_names,
        ):
            return False
        saw_call = True
    return saw_call


def _probe_blocked_sfi_write(name):
    def _blocked(*args, **kwargs):
        raise RuntimeError(
            f"probe-only hddid sidecar cannot call sfi.{name}() before the "
            "full hddid_clime module is loaded"
        )

    return _blocked


def _probe_make_readonly_sfi(real_sfi):
    probe_sfi = types.ModuleType("sfi")
    real_macro = getattr(real_sfi, "Macro", None)
    if real_macro is not None:
        macro_proxy = types.SimpleNamespace()
        if callable(getattr(real_macro, "getLocal", None)):
            macro_proxy.getLocal = real_macro.getLocal
        macro_proxy.setLocal = _probe_blocked_sfi_write("Macro.setLocal")
        probe_sfi.Macro = macro_proxy

    real_matrix = getattr(real_sfi, "Matrix", None)
    if real_matrix is not None:
        matrix_proxy = types.SimpleNamespace()
        if callable(getattr(real_matrix, "get", None)):
            matrix_proxy.get = real_matrix.get
        matrix_proxy.store = _probe_blocked_sfi_write("Matrix.store")
        probe_sfi.Matrix = matrix_proxy

    real_scalar = getattr(real_sfi, "Scalar", None)
    if real_scalar is not None:
        scalar_proxy = types.SimpleNamespace()
        if callable(getattr(real_scalar, "getValue", None)):
            scalar_proxy.getValue = real_scalar.getValue
        scalar_proxy.setValue = _probe_blocked_sfi_write("Scalar.setValue")
        probe_sfi.Scalar = scalar_proxy

    if getattr(real_sfi, "SFIToolkit", None) is not None:
        probe_sfi.SFIToolkit = types.SimpleNamespace(
            stata=_probe_blocked_sfi_write("SFIToolkit.stata")
        )

    return probe_sfi


@contextlib.contextmanager
def _probe_guarded_sfi(module):
    real_sfi = sys.modules.get("sfi")
    if real_sfi is None:
        yield
        return

    probe_sfi = _probe_make_readonly_sfi(real_sfi)
    old_sfi = real_sfi
    saved = {}
    for name in ("sfi", "Macro", "Matrix", "Scalar", "SFIToolkit"):
        if name in module.__dict__:
            saved[name] = (True, module.__dict__[name])
        else:
            saved[name] = (False, None)

    sys.modules["sfi"] = probe_sfi
    module.__dict__["sfi"] = probe_sfi
    for name in ("Macro", "Matrix", "Scalar", "SFIToolkit"):
        if hasattr(probe_sfi, name):
            module.__dict__[name] = getattr(probe_sfi, name)
        else:
            module.__dict__.pop(name, None)

    try:
        yield
    finally:
        sys.modules["sfi"] = old_sfi
        for name, (present, value) in saved.items():
            if present:
                module.__dict__[name] = value
            else:
                module.__dict__.pop(name, None)


def _probe_guard_callable_export(module, attr_name):
    func = getattr(module, attr_name, None)
    if not callable(func) or getattr(func, "_hddid_probe_sfi_guarded", False):
        return

    try:
        signature = inspect.signature(func)
    except (TypeError, ValueError):
        signature = None

    if inspect.isasyncgenfunction(func):

        @functools.wraps(func)
        async def guarded(*args, **kwargs):
            with _probe_guarded_sfi(module):
                async for item in func(*args, **kwargs):
                    yield item

    elif inspect.iscoroutinefunction(func):

        @functools.wraps(func)
        async def guarded(*args, **kwargs):
            with _probe_guarded_sfi(module):
                return await func(*args, **kwargs)

    else:

        @functools.wraps(func)
        def guarded(*args, **kwargs):
            with _probe_guarded_sfi(module):
                return func(*args, **kwargs)

    guarded._hddid_probe_sfi_guarded = True
    if signature is not None:
        guarded.__signature__ = signature
    setattr(module, attr_name, guarded)


def _probe_guard_runtime_exports(module):
    for attr_name in (
        "hddid_clime_requires_scipy",
    ):
        _probe_guard_callable_export(module, attr_name)


def main():
    _PROBE_SAFE_DICT_NAMES.clear()
    module_path = pathlib.Path(Macro.getLocal("_hddid_pyscript")).resolve()
    module_name = "_hddid_clime_" + hashlib.sha1(str(module_path).encode("utf-8")).hexdigest()
    probe_name = "__hddid_probe__" + module_name
    source_hash = hashlib.sha1(module_path.read_bytes()).hexdigest()

    current_numpy = sys.modules.get("numpy", numpy)
    numpy_file = (
        str(pathlib.Path(getattr(current_numpy, "__file__", "")).resolve())
        if getattr(current_numpy, "__file__", "")
        else ""
    )
    numpy_ver = str(getattr(current_numpy, "__version__", ""))
    numpy_id = id(current_numpy)

    scipy_mod = sys.modules.get("scipy")
    scipy_opt = sys.modules.get("scipy.optimize")
    scipy_file = str(pathlib.Path(getattr(scipy_mod, "__file__", "")).resolve()) if getattr(scipy_mod, "__file__", "") else ""
    scipy_ver = str(getattr(scipy_mod, "__version__", "")) if scipy_mod is not None else ""
    scipy_opt_file = (
        str(pathlib.Path(getattr(scipy_opt, "__file__", "")).resolve())
        if getattr(scipy_opt, "__file__", "")
        else ""
    )
    scipy_id = id(scipy_mod) if scipy_mod is not None else None
    scipy_opt_id = id(scipy_opt) if scipy_opt is not None else None

    main_module = sys.modules.get(module_name)
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
    probe_only_cached = bool(
        probe_ok and getattr(probe_module, "_hddid_safe_probe_only", 0)
    )
    module = (
        probe_module
        if probe_only_cached
        else (
            main_module
            if main_ok
            else (
                probe_module
                if probe_ok
                else (main_module if main_module is not None else probe_module)
            )
        )
    )

    module_file = getattr(module, "__file__", None) if module is not None else None
    cached_path = pathlib.Path(module_file).resolve() if module_file else None
    cached_hash = getattr(module, "_hddid_source_hash", None) if module is not None else None
    cached_numpy_file = getattr(module, "_hddid_numpy_file", None) if module is not None else None
    cached_numpy_ver = getattr(module, "_hddid_numpy_ver", None) if module is not None else None
    cached_numpy_id = getattr(module, "_hddid_numpy_id", None) if module is not None else None
    cached_scipy_file = getattr(module, "_hddid_scipy_file", None) if module is not None else None
    cached_scipy_ver = getattr(module, "_hddid_scipy_ver", None) if module is not None else None
    cached_scipy_opt_file = getattr(module, "_hddid_scipy_opt_file", None) if module is not None else None
    cached_scipy_id = getattr(module, "_hddid_scipy_id", None) if module is not None else None
    cached_scipy_opt_id = getattr(module, "_hddid_scipy_opt_id", None) if module is not None else None

    dep_changed = (
        module is None
        or cached_numpy_file != numpy_file
        or cached_numpy_ver != numpy_ver
        or cached_numpy_id != numpy_id
        or cached_scipy_file != scipy_file
        or cached_scipy_ver != scipy_ver
        or cached_scipy_id != scipy_id
        or cached_scipy_opt_file != scipy_opt_file
        or cached_scipy_opt_id != scipy_opt_id
    )
    needs_reload = (
        module is None
        or cached_path != module_path
        or cached_hash != source_hash
        or dep_changed
        or not bool(getattr(module, "_hddid_safe_probe_only", 0))
    )

    if needs_reload:
        spec = importlib.util.spec_from_file_location(module_name, module_path)
        if spec is None or spec.loader is None:
            raise ImportError(f"Unable to create import spec for {module_path}")

        module = importlib.util.module_from_spec(spec)
        probe_source = module_path.read_text(encoding="utf-8")
        probe_tree = ast.parse(probe_source, filename=str(module_path))
        _PROBE_SAFE_DICT_NAMES.clear()
        _PROBE_SAFE_GETATTR_NAMES.clear()
        _PROBE_SAFE_SIGNATURELIKE_NAMES.clear()
        _PROBE_SAFE_SIGNATURE_CLASS_NAMES.clear()
        _PROBE_SAFE_SIMPLENAMESPACE_NAMES.clear()
        probe_import_roots = {"np", "numpy", "sys"}
        probe_safe_import_modules = {
            "builtins",
            "collections",
            "numpy",
            "sys",
            "sfi",
            "pathlib",
            "inspect",
            "functools",
            "math",
            "types",
            "__future__",
        }
        probe_safe_names = {"__file__"}
        probe_safe_ctor_names = set()
        probe_safe_calls = {
            "abs",
            "all",
            "any",
            "bool",
            "callable",
            "classmethod",
            "dict",
            "enumerate",
            "frozenset",
            "getattr",
            "hasattr",
            "id",
            "isinstance",
            "inspect.Parameter",
            "inspect.Signature",
            "inspect.Signature.from_callable",
            "inspect.signature",
            "int",
            "float",
            "iter",
            "list",
            "object",
            "round",
            "range",
            "reversed",
            "set",
            "slice",
            "sorted",
            "str",
            "type",
            "len",
            "map",
            "max",
            "min",
            "next",
            "pathlib.Path",
            "partial",
            "sum",
            "tuple",
            "zip",
            "staticmethod",
            "builtins.staticmethod",
            "builtins.classmethod",
            "np.float64",
            "np.iinfo",
            "functools.partial",
            "sys.modules.get",
            "types.SimpleNamespace",
        }
        _PROBE_SAFE_GETATTR_NAMES.update({"getattr", "builtins.getattr"})
        _PROBE_SAFE_SIGNATURE_CLASS_NAMES.update({"inspect.Signature"})
        _PROBE_SAFE_SIGNATURELIKE_NAMES.update(
            {
                "inspect.signature",
                "inspect.Signature",
                "inspect.Signature.from_callable",
            }
        )
        _PROBE_SAFE_SIMPLENAMESPACE_NAMES.update({"types.SimpleNamespace"})
        probe_safe_object_base_names = {"object", "builtins.object"}
        probe_safe_staticmethod_names = {
            "staticmethod",
            "builtins.staticmethod",
        }
        probe_safe_classmethod_names = {
            "classmethod",
            "builtins.classmethod",
        }
        probe_safe_binding_exprs = {}

        for node in probe_tree.body:
            if isinstance(node, ast.Import):
                for alias in node.names:
                    root = alias.name.split(".")[0]
                    if root in probe_safe_import_modules:
                        imported_name = alias.asname or root
                        probe_import_roots.add(imported_name)
                        if root == "builtins":
                            _PROBE_SAFE_GETATTR_NAMES.add(
                                f"{imported_name}.getattr"
                            )
                            probe_safe_calls.add(f"{imported_name}.getattr")
                            probe_safe_object_base_names.add(
                                f"{imported_name}.object"
                            )
                            probe_safe_staticmethod_names.add(
                                f"{imported_name}.staticmethod"
                            )
                            probe_safe_classmethod_names.add(
                                f"{imported_name}.classmethod"
                            )
                        if root == "inspect":
                            _PROBE_SAFE_SIGNATURE_CLASS_NAMES.add(
                                f"{imported_name}.Signature"
                            )
                            _PROBE_SAFE_SIGNATURELIKE_NAMES.update(
                                {
                                    f"{imported_name}.signature",
                                    f"{imported_name}.Signature",
                                    f"{imported_name}.Signature.from_callable",
                                }
                            )
                            probe_safe_calls.update(
                                {
                                    f"{imported_name}.signature",
                                    f"{imported_name}.Signature",
                                    f"{imported_name}.Signature.from_callable",
                                }
                            )
                        if root == "types":
                            _PROBE_SAFE_SIMPLENAMESPACE_NAMES.add(
                                f"{imported_name}.SimpleNamespace"
                            )
                            probe_safe_calls.add(
                                f"{imported_name}.SimpleNamespace"
                            )
            elif isinstance(node, ast.ImportFrom):
                root = (node.module or "").split(".")[0]
                if root in probe_safe_import_modules:
                    for alias in node.names:
                        imported_name = alias.asname or alias.name
                        probe_import_roots.add(imported_name)
                        if root == "builtins" and alias.name == "object":
                            probe_safe_object_base_names.add(imported_name)
                        if root == "builtins" and alias.name == "getattr":
                            _PROBE_SAFE_GETATTR_NAMES.add(imported_name)
                            probe_safe_calls.add(imported_name)
                        if root == "builtins" and alias.name == "staticmethod":
                            probe_safe_staticmethod_names.add(imported_name)
                        if root == "builtins" and alias.name == "classmethod":
                            probe_safe_classmethod_names.add(imported_name)
                        if root == "inspect" and alias.name == "signature":
                            _PROBE_SAFE_SIGNATURELIKE_NAMES.add(imported_name)
                            probe_safe_calls.add(imported_name)
                        if root == "inspect" and alias.name == "Signature":
                            _PROBE_SAFE_SIGNATURE_CLASS_NAMES.add(imported_name)
                            _PROBE_SAFE_SIGNATURELIKE_NAMES.update(
                                {
                                    imported_name,
                                    f"{imported_name}.from_callable",
                                }
                            )
                            probe_safe_calls.update(
                                {
                                    imported_name,
                                    f"{imported_name}.from_callable",
                                }
                            )
                        if root == "types" and alias.name == "SimpleNamespace":
                            _PROBE_SAFE_SIMPLENAMESPACE_NAMES.add(imported_name)
                            probe_safe_calls.add(imported_name)

        probe_body = []
        for node in probe_tree.body:
            docstring_ok = (
                isinstance(node, ast.Expr)
                and isinstance(getattr(node, "value", None), ast.Constant)
                and isinstance(node.value.value, str)
            )
            import_ok = (
                isinstance(node, ast.Import)
                and all(alias.name.split(".")[0] in probe_safe_import_modules for alias in node.names)
            ) or (
                isinstance(node, ast.ImportFrom)
                and (node.module or "").split(".")[0] in probe_safe_import_modules
                and all(alias.name != "*" for alias in node.names)
            )
            assign_ok = isinstance(node, (ast.Assign, ast.AnnAssign)) and _probe_targets_ok(node) and _probe_safe_expr(
                node.value,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            def_ok = _probe_sanitize_def(
                node,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
            )
            class_ok = _probe_sanitize_class(
                node,
                probe_import_roots,
                probe_safe_names,
                probe_safe_calls,
                probe_safe_ctor_names,
                probe_safe_object_base_names,
                _PROBE_SAFE_SIMPLENAMESPACE_NAMES,
                probe_safe_staticmethod_names,
                probe_safe_classmethod_names,
                probe_safe_binding_exprs,
            )
            if docstring_ok or import_ok or assign_ok or def_ok or class_ok:
                probe_body.append(
                    _probe_strip_annotations(node)
                    if (assign_ok or def_ok or class_ok)
                    else node
                )
                if assign_ok:
                    _probe_register_targets(node, probe_safe_names)
                    _probe_register_destructurable_bindings(
                        node,
                        probe_safe_binding_exprs,
                    )
                    _probe_register_assigned_object_base_aliases(
                        node,
                        probe_safe_object_base_names,
                        probe_safe_binding_exprs,
                    )
                    _probe_register_assigned_getattr_aliases(
                        node,
                        probe_safe_calls,
                        probe_safe_binding_exprs=probe_safe_binding_exprs,
                    )
                    _probe_register_assigned_staticmethod_aliases(
                        node,
                        probe_safe_staticmethod_names,
                        probe_safe_binding_exprs,
                    )
                    _probe_register_assigned_classmethod_aliases(
                        node,
                        probe_safe_classmethod_names,
                        probe_safe_binding_exprs,
                    )
                    _probe_register_assigned_signaturelike_aliases(
                        node,
                        probe_safe_calls,
                        probe_safe_binding_exprs=probe_safe_binding_exprs,
                    )
                    _probe_register_assigned_simplenamespace_aliases(
                        node,
                        _PROBE_SAFE_SIMPLENAMESPACE_NAMES,
                        probe_safe_calls,
                        probe_safe_binding_exprs,
                    )
                    _probe_register_safe_dict_targets(
                        node,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                        probe_safe_binding_exprs,
                    )
                if def_ok:
                    _probe_register_def(node, probe_safe_names)
                    if _probe_sanitize_zero_arg_ctor_function(
                        node,
                        probe_import_roots,
                        probe_safe_names,
                        probe_safe_calls,
                        probe_safe_ctor_names,
                    ):
                        probe_safe_ctor_names.add(node.name)
                if class_ok:
                    probe_safe_ctor_names.add(node.name)

        probe_mod = ast.fix_missing_locations(
            ast.Module(body=probe_body, type_ignores=getattr(probe_tree, "type_ignores", []))
        )

        module.__dict__.setdefault("np", current_numpy)
        module.__dict__.setdefault("numpy", current_numpy)
        module.__dict__.setdefault("sys", sys)
        probe_sfi = sys.modules.get("sfi")
        if probe_sfi is not None:
            module.__dict__.setdefault("sfi", probe_sfi)
            if hasattr(probe_sfi, "Matrix"):
                module.__dict__.setdefault("Matrix", getattr(probe_sfi, "Matrix"))
            if hasattr(probe_sfi, "Scalar"):
                module.__dict__.setdefault("Scalar", getattr(probe_sfi, "Scalar"))
            if hasattr(probe_sfi, "Macro"):
                module.__dict__.setdefault("Macro", getattr(probe_sfi, "Macro"))
            if hasattr(probe_sfi, "SFIToolkit"):
                module.__dict__.setdefault("SFIToolkit", getattr(probe_sfi, "SFIToolkit"))

        # Execute the sanitized probe module under the same read-only SFI
        # guard used for runtime helper calls so top-level imports/aliases such
        # as `WRITE = Scalar.setValue` cannot freeze a writable Stata handle
        # into the probe-only namespace before preflight begins.
        with _probe_guarded_sfi(module):
            exec(compile(probe_mod, str(module_path), "exec"), module.__dict__)
        setattr(module, "_hddid_safe_probe_only", 1)
    else:
        setattr(module, "_hddid_safe_probe_only", 1 if bool(getattr(module, "_hddid_safe_probe_only", 0)) else 0)

    setattr(module, "_hddid_source_hash", source_hash)
    setattr(module, "_hddid_numpy_file", numpy_file)
    setattr(module, "_hddid_numpy_ver", numpy_ver)
    setattr(module, "_hddid_numpy_id", numpy_id)
    setattr(module, "_hddid_scipy_file", scipy_file)
    setattr(module, "_hddid_scipy_ver", scipy_ver)
    setattr(module, "_hddid_scipy_id", scipy_id)
    setattr(module, "_hddid_scipy_opt_file", scipy_opt_file)
    setattr(module, "_hddid_scipy_opt_id", scipy_opt_id)

    probe_only = bool(getattr(module, "_hddid_safe_probe_only", 0))
    if probe_only:
        # Probe-only cache entries are sanitized feasibility snapshots, not
        # authoritative runtime-solve sidecars. Drop any stale bridge that may
        # have been attached to a reused module object before re-publishing the
        # probe namespace so downstream runtime gates cannot mistake it for a
        # full CLIME module.
        module.__dict__.pop("_hddid_bridge_call_clime_solve", None)
        # Downstream ado bridge lookups prefer the main-module cache when both
        # names resolve to the requested path. If a probe-only refresh leaves a
        # stale same-path main module behind, the bridge can keep consulting the
        # pre-refresh namespace instead of the freshly sanitized probe module.
        sys.modules.pop(module_name, None)
        sys.modules[probe_name] = module
    else:
        sys.modules.pop(probe_name, None)
        sys.modules[module_name] = module
    obj = getattr(module, "hddid_clime_solve", None)
    call = getattr(obj, "__call__", None) if obj is not None else None
    generator_solver = bool(
        obj is not None
        and callable(obj)
        and (
            inspect.isgeneratorfunction(obj)
            or (call is not None and inspect.isgeneratorfunction(call))
        )
    )
    async_generator_solver = bool(
        obj is not None
        and callable(obj)
        and (
            inspect.isasyncgenfunction(obj)
            or (call is not None and inspect.isasyncgenfunction(call))
        )
    )
    async_solver = bool(
        obj is not None
        and callable(obj)
        and (
            inspect.iscoroutinefunction(obj)
            or (call is not None and inspect.iscoroutinefunction(call))
            or async_generator_solver
        )
    )
    Macro.setLocal("_hddid_py_module", module_name)
    Macro.setLocal("_hddid_py_clime_present", str(1 if obj is not None else 0))
    Macro.setLocal(
        "_hddid_py_clime_callable",
        str(1 if callable(obj) and not generator_solver and not async_solver else 0),
    )
    Macro.setLocal(
        "_hddid_py_clime_type",
        (
            "generator function"
            if generator_solver
            else (
                "async generator function"
                if async_generator_solver
                else ("async function" if async_solver else type(obj).__name__)
            )
        ),
    )
    if probe_only:
        _probe_guard_runtime_exports(module)


if __name__ == "__main__":
    main()
