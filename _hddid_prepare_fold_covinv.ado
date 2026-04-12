/*! version 1.0.0 */
capture program drop _hddid_pfc_restore
program define _hddid_pfc_restore
    version 16
    syntax , NFRESTORE(integer) RAWRESTORE(integer) ///
        NFPRIOR(name) RAWPRIOR(name)

    if `nfrestore' {
        capture scalar drop __hddid_clime_effective_nfolds
        scalar __hddid_clime_effective_nfolds = scalar(`nfprior')
    }
    else {
        capture scalar drop __hddid_clime_effective_nfolds
    }

    if `rawrestore' {
        capture scalar drop __hddid_clime_raw_feasible
        scalar __hddid_clime_raw_feasible = scalar(`rawprior')
    }
    else {
        capture scalar drop __hddid_clime_raw_feasible
    }
end

capture program drop _hddid_pfc_run_rng_isolated
program define _hddid_pfc_run_rng_isolated
    version 16

    capture quietly program list _hddid_run_rng_isolated
    if _rc == 0 {
        capture _hddid_run_rng_isolated `0'
        exit _rc
    }

    gettoken seed 0 : 0, parse(" ")
    capture confirm number `seed'
    if _rc != 0 {
        di as error "{bf:hddid}: internal RNG-isolation wrapper received a nonnumeric seed contract"
        exit 198
    }
    local _seed_num = real(`"`seed'"')
    if missing(`_seed_num') | `_seed_num' != floor(`_seed_num') | ///
        `_seed_num' < -1 | `_seed_num' > 2147483647 {
        di as error "{bf:hddid}: internal RNG-isolation wrapper requires seed() equal to -1 or an integer in [0, 2147483647]"
        di as error "  Received internal seed contract = {bf:`seed'}"
        exit 198
    }

    local _restore_rngstate = (`_seed_num' >= 0)
    local _use_active_stream 0
    local _resume_isolated_stream 0
    if `_seed_num' >= 0 & ///
        `"$HDDID_ACTIVE_INTERNAL_RNG_STREAM"' == "1" & ///
        `"$HDDID_ACTIVE_INTERNAL_SEED"' != "" {
        capture confirm number $HDDID_ACTIVE_INTERNAL_SEED
        if _rc == 0 {
            local _active_seed_num = real(`"$HDDID_ACTIVE_INTERNAL_SEED"')
            if !missing(`_active_seed_num') & ///
                `_active_seed_num' == floor(`_active_seed_num') & ///
                `_active_seed_num' == `_seed_num' {
                local _use_active_stream 1
                local _restore_rngstate 0
            }
        }
    }
    local _rngstate_before `c(rngstate)'
    if `_seed_num' >= 0 & !`_use_active_stream' & ///
        `"$HDDID_LASTISO_SEED"' != "" & ///
        `"$HDDID_LASTISO_CALLER_RNG"' != "" & ///
        `"$HDDID_LASTISO_INTERNAL_RNG"' != "" {
        capture confirm number $HDDID_LASTISO_SEED
        if _rc == 0 {
            local _isolated_seed_num = real(`"$HDDID_LASTISO_SEED"')
            if !missing(`_isolated_seed_num') & ///
                `_isolated_seed_num' == floor(`_isolated_seed_num') & ///
                `_isolated_seed_num' == `_seed_num' & ///
                `"`_rngstate_before'"' == `"$HDDID_LASTISO_CALLER_RNG"' {
                local _resume_isolated_stream 1
            }
        }
    }
    if `_seed_num' >= 0 & !`_use_active_stream' {
        if `_resume_isolated_stream' {
            quietly set rngstate $HDDID_LASTISO_INTERNAL_RNG
        }
        else {
            quietly set seed `_seed_num'
        }
    }

    capture `0'
    local _cmd_rc = _rc
    if `_cmd_rc' == 0 & `_seed_num' >= 0 & !`_use_active_stream' {
        global HDDID_LASTISO_SEED `_seed_num'
        global HDDID_LASTISO_CALLER_RNG `"`_rngstate_before'"'
        global HDDID_LASTISO_INTERNAL_RNG `"`c(rngstate)'"'
    }

    if `_restore_rngstate' | (`_cmd_rc' != 0 & `_use_active_stream') {
        quietly set rngstate `_rngstate_before'
    }

    exit `_cmd_rc'
end

capture program drop _hddid_pfc_uncache_scipy
program define _hddid_pfc_uncache_scipy
    version 16

    capture quietly program list _hddid_uncache_scipy
    if _rc == 0 {
        quietly _hddid_uncache_scipy
        exit _rc
    }

    capture python: import importlib, sys; _mods = [m for m in list(sys.modules) if m == "scipy" or m.startswith("scipy.")]; _trash = [sys.modules.pop(m, None) for m in _mods]; importlib.invalidate_caches()
    exit _rc
end

capture program drop _hddid_pfc_uncache_numpy
program define _hddid_pfc_uncache_numpy
    version 16

    capture quietly program list _hddid_uncache_numpy
    if _rc == 0 {
        quietly _hddid_uncache_numpy
        exit _rc
    }

    capture python: import importlib, sys; _mods = [m for m in list(sys.modules) if m == "numpy" or m.startswith("numpy.")]; _trash = [sys.modules.pop(m, None) for m in _mods]; importlib.invalidate_caches()
    exit _rc
end

capture program drop _hddid_pfc_clime_feas_ok
program define _hddid_pfc_clime_feas_ok, rclass
    version 16
    args gap cap tol raw

    capture quietly program list _hddid_clime_feas_ok
    if _rc == 0 {
        _hddid_clime_feas_ok `gap' `cap' `tol' `raw'
        exit _rc
    }

    return clear

    local _raw_feasible 0
    if "`raw'" != "" {
        local _raw_feasible = `raw'
    }

    if missing(`gap') | missing(`cap') | missing(`tol') | missing(`_raw_feasible') {
        di as error "{bf:hddid}: CLIME published-feasibility helper received missing numeric input"
        exit 198
    }
    if `cap' < 0 | `tol' < 0 {
        di as error "{bf:hddid}: CLIME published-feasibility helper requires nonnegative cap() and tol()"
        exit 198
    }
    if `gap' < 0 {
        di as error "{bf:hddid}: CLIME published-feasibility helper requires a nonnegative gap()"
        exit 198
    }
    if `_raw_feasible' != floor(`_raw_feasible') | !inlist(`_raw_feasible', 0, 1) {
        di as error "{bf:hddid}: CLIME published-feasibility helper requires rawfeasible() to be 0 or 1"
        exit 198
    }

    if `_raw_feasible' == 1 {
        return scalar allowed = 1
        return scalar raw_feasible = 1
        return scalar relaxed_gap = `gap'
        return scalar cap = `cap'
        return scalar tol = `tol'
        exit
    }

    return scalar allowed = (`gap' <= `cap' + `tol')
    return scalar raw_feasible = 0
    return scalar relaxed_gap = `gap'
    return scalar cap = `cap'
    return scalar tol = `tol'
end

capture program drop _hddid_pfc_clime_scipy_probe
program define _hddid_pfc_clime_scipy_probe, rclass
    version 16
    syntax , SCRIPT(string) MODULE(string) TILDEX(name)

    capture quietly program list _hddid_clime_scipy_probe
    if _rc == 0 {
        _hddid_clime_scipy_probe, script("`script'") module("`module'") tildex(`tildex')
        if _rc == 0 {
            return clear
            return local needs_scipy `"`r(needs_scipy)'"'
        }
        exit _rc
    }

    return clear
    local _hddid_clime_needs_scipy ""
    capture python: ///
        import importlib.util, inspect, pathlib, sys; ///
        import hashlib; ///
        _module_path = pathlib.Path(r"`script'").resolve(); ///
        _module_name = r"`module'"; ///
        _probe_name = "__hddid_probe__" + _module_name; ///
        _main_module = sys.modules.get(_module_name); ///
        _probe_module = sys.modules.get(_probe_name); ///
        _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
        _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
        _module = _main_module if _main_ok else (_probe_module if _probe_ok else None); ///
        _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
        _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
        _probe_only = bool(getattr(_module, "_hddid_safe_probe_only", 0)) if _module is not None else False; ///
        exec("if _module is None or _probe_only or _cached_hash != _source_hash:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cached_hash = _source_hash\n    _probe_only = False"); ///
        _helper = getattr(_module, "hddid_clime_requires_scipy", None); ///
        _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
        _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
        _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
        (_ for _ in ()).throw(AttributeError("hddid_clime_requires_scipy() helper missing")) if _helper is None else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must be a synchronous callable, got {'async generator function' if _helper_asyncgen else 'async function'}")) if (callable(_helper) and _helper_async) else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must be callable, got {type(_helper).__name__}")) if (not callable(_helper)) else None
    if _rc != 0 {
        exit _rc
    }
    capture python: ///
        from sfi import Macro; import functools, importlib.util, inspect, numpy as _np, pathlib, sys; ///
        import hashlib; ///
        _module_path = pathlib.Path(r"`script'").resolve(); ///
        _module_name = r"`module'"; ///
        _probe_name = "__hddid_probe__" + _module_name; ///
        _main_module = sys.modules.get(_module_name); ///
        _probe_module = sys.modules.get(_probe_name); ///
        _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
        _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
        _module = _main_module if _main_ok else (_probe_module if _probe_ok else None); ///
        _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
        _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
        _probe_only = bool(getattr(_module, "_hddid_safe_probe_only", 0)) if _module is not None else False; ///
        exec("if _module is None or _probe_only or _cached_hash != _source_hash:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cached_hash = _source_hash\n    _probe_only = False"); ///
        _helper = getattr(_module, "hddid_clime_requires_scipy"); ///
        _helper_call = getattr(_helper, "__call__", None); ///
        _helper_positional = []; ///
        _helper_kwargs = {"perturb": True}; ///
        exec("try:\n    _helper_sig_target = _helper\n    _prefer_object_sig = isinstance(_helper, functools.partial)\n    if _prefer_object_sig:\n        _helper_partial_func = _helper.func\n        _helper_partial_call = getattr(_helper_partial_func, \"__call__\", None)\n        if _helper_partial_call is not None and _helper_partial_call is not _helper_partial_func and not inspect.isclass(_helper_partial_func) and not (inspect.isfunction(_helper_partial_func) or inspect.ismethod(_helper_partial_func) or inspect.isbuiltin(_helper_partial_func) or inspect.isroutine(_helper_partial_func)):\n            try:\n                _helper_sig_target = functools.partial(_helper_partial_call, *(_helper.args or ()), **(_helper.keywords or {}))\n                _prefer_object_sig = False\n            except TypeError:\n                _helper_sig_target = _helper\n                _prefer_object_sig = True\n    if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n        _helper_sig_target = _helper_call\n    _helper_sig = ((_module._resolve_bridge_signature(_helper)) or inspect.signature(_helper_sig_target, follow_wrapped=False)) if callable(getattr(_module, \"_resolve_bridge_signature\", None)) else inspect.signature(_helper_sig_target, follow_wrapped=False)\nexcept (TypeError, ValueError):\n    _helper_sig = None\nif _helper_sig is not None:\n    _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_sig.parameters.values())\n    for _p in _helper_sig.parameters.values():\n        if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n            _helper_positional.append(_helper_kwargs.pop(_p.name))\n    if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n        _helper_positional.append(_helper_kwargs.pop('perturb'))\n_raw_needs = _helper(r'`tildex'', *_helper_positional, **_helper_kwargs)"); ///
        _raw_needs_generator = bool(inspect.isgenerator(_raw_needs)); ///
        _raw_needs_asyncgen = bool(inspect.isasyncgen(_raw_needs)) if not _raw_needs_generator else False; ///
        _raw_needs_awaitable = bool(inspect.isawaitable(_raw_needs)) if not _raw_needs_generator and not _raw_needs_asyncgen else False; ///
        _raw_needs_close = getattr(_raw_needs, "close", None) if _raw_needs_generator else (getattr(_raw_needs, "aclose", None) if _raw_needs_asyncgen else (getattr(_raw_needs, "close", None) if _raw_needs_awaitable else None)); ///
        _raw_needs_close_ret = _raw_needs_close() if callable(_raw_needs_close) else None; ///
        _raw_needs_close_ret_close = getattr(_raw_needs_close_ret, "close", None) if _raw_needs_asyncgen else None; ///
        _raw_needs_close_ret_close() if callable(_raw_needs_close_ret_close) else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got generator {type(_raw_needs).__name__}")) if _raw_needs_generator else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got async generator {type(_raw_needs).__name__}")) if _raw_needs_asyncgen else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got awaitable {type(_raw_needs).__name__}")) if _raw_needs_awaitable else None; ///
        (_ for _ in ()).throw(TypeError("hddid_clime_requires_scipy() must return a bool")) if not isinstance(_raw_needs, (bool, _np.bool_)) else None; ///
        Macro.setLocal("_hddid_clime_needs_scipy", str(int(bool(_raw_needs))))
    if _rc != 0 {
        exit _rc
    }
    return local needs_scipy "`_hddid_clime_needs_scipy'"
end

capture program drop _hddid_pfc_probe_fail_classify
program define _hddid_pfc_probe_fail_classify, rclass
    version 16
    syntax , SCRIPT(string) MODULE(string) TILDEX(name)

    capture quietly program list _hddid_probe_fail_classify
    if _rc == 0 {
        _hddid_probe_fail_classify, script("`script'") module("`module'") tildex(`tildex')
        if _rc == 0 {
            return clear
            return local reason `"`r(reason)'"'
        }
        exit _rc
    }

    return clear
    local _hddid_probe_reason ""
    capture python: ///
        from sfi import Macro; import functools, inspect, numpy as _np, pathlib, sys; ///
        import hashlib, importlib.util; ///
        _module_path = pathlib.Path(r"`script'").resolve(); ///
        _module_name = r"`module'"; ///
        _probe_name = "__hddid_probe__" + _module_name; ///
        _main_module = sys.modules.get(_module_name); ///
        _probe_module = sys.modules.get(_probe_name); ///
        _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
        _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
        _module = _main_module if _main_ok else (_probe_module if _probe_ok else (_main_module if _main_module is not None else _probe_module)); ///
        _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
        _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
        _cache_ok = (_main_ok or _probe_ok) and (_cached_hash == _source_hash); ///
        exec("if not _cache_ok:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cache_ok = True") if _module is None or not _cache_ok else None; ///
        Macro.setLocal("_hddid_probe_reason", "cache_missing" if not _cache_ok else ""); ///
        _helper = None if not _cache_ok else getattr(_module, "hddid_clime_requires_scipy", None); ///
        _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
        _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
        _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
        Macro.setLocal("_hddid_probe_reason", "helper_missing" if _cache_ok and _helper is None else Macro.getLocal("_hddid_probe_reason")); ///
        Macro.setLocal("_hddid_probe_reason", "helper_noncallable" if _cache_ok and _helper is not None and ((not callable(_helper)) or _helper_async) else Macro.getLocal("_hddid_probe_reason")); ///
        _raw_needs = None; ///
        _helper_positional = []; ///
        _helper_kwargs = {"perturb": True}; ///
        exec("try:\n    _helper_sig_target = _helper\n    _prefer_object_sig = isinstance(_helper, functools.partial)\n    if _prefer_object_sig:\n        _helper_partial_func = _helper.func\n        _helper_partial_call = getattr(_helper_partial_func, \"__call__\", None)\n        if _helper_partial_call is not None and _helper_partial_call is not _helper_partial_func and not inspect.isclass(_helper_partial_func) and not (inspect.isfunction(_helper_partial_func) or inspect.ismethod(_helper_partial_func) or inspect.isbuiltin(_helper_partial_func) or inspect.isroutine(_helper_partial_func)):\n            try:\n                _helper_sig_target = functools.partial(_helper_partial_call, *(_helper.args or ()), **(_helper.keywords or {}))\n                _prefer_object_sig = False\n            except TypeError:\n                _helper_sig_target = _helper\n                _prefer_object_sig = True\n    if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n        _helper_sig_target = _helper_call\n    _helper_sig = ((_module._resolve_bridge_signature(_helper)) or inspect.signature(_helper_sig_target, follow_wrapped=False)) if callable(getattr(_module, \"_resolve_bridge_signature\", None)) else inspect.signature(_helper_sig_target, follow_wrapped=False)\nexcept Exception:\n    pass\nelse:\n    _helper_params = _helper_sig.parameters\n    _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_params.values())\n    for _p in _helper_params.values():\n        if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n            _helper_positional.append(_helper_kwargs.pop(_p.name))\n    if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n        _helper_positional.append(_helper_kwargs.pop('perturb'))") if Macro.getLocal("_hddid_probe_reason") == "" and callable(_helper) and not _helper_async else None; ///
        _probe_reason = Macro.getLocal("_hddid_probe_reason"); ///
        _raw_needs = _helper("`tildex'", *_helper_positional, **_helper_kwargs) if _probe_reason == "" else None; ///
        _raw_needs_generator = bool(inspect.isgenerator(_raw_needs)) if Macro.getLocal("_hddid_probe_reason") == "" else False; ///
        _raw_needs_asyncgen = bool(inspect.isasyncgen(_raw_needs)) if Macro.getLocal("_hddid_probe_reason") == "" and not _raw_needs_generator else False; ///
        _raw_needs_awaitable = bool(inspect.isawaitable(_raw_needs)) if Macro.getLocal("_hddid_probe_reason") == "" and not _raw_needs_generator and not _raw_needs_asyncgen else False; ///
        _raw_needs_close = getattr(_raw_needs, "close", None) if _raw_needs_generator else (getattr(_raw_needs, "aclose", None) if _raw_needs_asyncgen else (getattr(_raw_needs, "close", None) if _raw_needs_awaitable else None)); ///
        _raw_needs_close_ret = _raw_needs_close() if callable(_raw_needs_close) else None; ///
        _raw_needs_close_ret_close = getattr(_raw_needs_close_ret, "close", None) if _raw_needs_asyncgen else None; ///
        _raw_needs_close_ret_close() if callable(_raw_needs_close_ret_close) else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got generator {type(_raw_needs).__name__}")) if Macro.getLocal("_hddid_probe_reason") == "" and _raw_needs_generator else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got async generator {type(_raw_needs).__name__}")) if Macro.getLocal("_hddid_probe_reason") == "" and _raw_needs_asyncgen else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got awaitable {type(_raw_needs).__name__}")) if Macro.getLocal("_hddid_probe_reason") == "" and _raw_needs_awaitable else None; ///
        Macro.setLocal("_hddid_probe_reason", "helper_nonbool" if Macro.getLocal("_hddid_probe_reason") == "" and not isinstance(_raw_needs, (bool, _np.bool_)) else Macro.getLocal("_hddid_probe_reason")); ///
        Macro.setLocal("_hddid_probe_reason", "ok" if Macro.getLocal("_hddid_probe_reason") == "" else Macro.getLocal("_hddid_probe_reason"))
    if _rc != 0 {
        capture python: ///
            from sfi import Macro; import functools, inspect, numpy as _np, pathlib, sys; ///
            import hashlib, importlib.util; ///
            _module_path = pathlib.Path(r"`script'").resolve(); ///
            _module_name = r"`module'"; ///
            _probe_name = "__hddid_probe__" + _module_name; ///
            _main_module = sys.modules.get(_module_name); ///
            _probe_module = sys.modules.get(_probe_name); ///
            _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
            _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
            _module = _main_module if _main_ok else (_probe_module if _probe_ok else (_main_module if _main_module is not None else _probe_module)); ///
            _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
            _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
            _cache_ok = (_main_ok or _probe_ok) and (_cached_hash == _source_hash); ///
            exec("if not _cache_ok:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cache_ok = True") if _module is None or not _cache_ok else None; ///
            Macro.setLocal("_hddid_probe_reason", "cache_missing" if not _cache_ok else ""); ///
            _helper = None if not _cache_ok else getattr(_module, "hddid_clime_requires_scipy", None); ///
            _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
            _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
            _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
            Macro.setLocal("_hddid_probe_reason", "helper_missing" if _cache_ok and _helper is None else Macro.getLocal("_hddid_probe_reason")); ///
            Macro.setLocal("_hddid_probe_reason", "helper_noncallable" if _cache_ok and _helper is not None and ((not callable(_helper)) or _helper_async) else Macro.getLocal("_hddid_probe_reason")); ///
            exec("try:\n    _helper_positional = []\n    _helper_kwargs = {'perturb': True}\n    _helper_sig_target = _helper\n    _prefer_object_sig = isinstance(_helper, functools.partial)\n    if _prefer_object_sig:\n        _helper_partial_func = _helper.func\n        _helper_partial_call = getattr(_helper_partial_func, \"__call__\", None)\n        if _helper_partial_call is not None and _helper_partial_call is not _helper_partial_func and not inspect.isclass(_helper_partial_func) and not (inspect.isfunction(_helper_partial_func) or inspect.ismethod(_helper_partial_func) or inspect.isbuiltin(_helper_partial_func) or inspect.isroutine(_helper_partial_func)):\n            try:\n                _helper_sig_target = functools.partial(_helper_partial_call, *(_helper.args or ()), **(_helper.keywords or {}))\n                _prefer_object_sig = False\n            except TypeError:\n                _helper_sig_target = _helper\n                _prefer_object_sig = True\n    if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n        _helper_sig_target = _helper_call\n    try:\n        _helper_sig = ((_module._resolve_bridge_signature(_helper)) or inspect.signature(_helper_sig_target, follow_wrapped=False)) if callable(getattr(_module, \"_resolve_bridge_signature\", None)) else inspect.signature(_helper_sig_target, follow_wrapped=False)\n    except Exception:\n        pass\n    else:\n        _helper_params = _helper_sig.parameters\n        _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_params.values())\n        for _p in _helper_params.values():\n            if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n                _helper_positional.append(_helper_kwargs.pop(_p.name))\n        if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n            _helper_positional.append(_helper_kwargs.pop('perturb'))\n    _helper_result = _helper(\"`tildex'\", *_helper_positional, **_helper_kwargs)\n    _helper_result_generator = bool(inspect.isgenerator(_helper_result))\n    _helper_result_asyncgen = bool(inspect.isasyncgen(_helper_result)) if not _helper_result_generator else False\n    _helper_result_awaitable = bool(inspect.isawaitable(_helper_result)) if not _helper_result_generator and not _helper_result_asyncgen else False\n    _helper_result_close = getattr(_helper_result, \"close\", None) if _helper_result_generator else (getattr(_helper_result, \"aclose\", None) if _helper_result_asyncgen else (getattr(_helper_result, \"close\", None) if _helper_result_awaitable else None))\n    _helper_result_close_ret = _helper_result_close() if callable(_helper_result_close) else None\n    _helper_result_close_ret_close = getattr(_helper_result_close_ret, \"close\", None) if _helper_result_asyncgen else None\n    _helper_result_close_ret_close() if callable(_helper_result_close_ret_close) else None\n    (_ for _ in ()).throw(TypeError(f\"hddid_clime_requires_scipy() must return synchronously, got generator {type(_helper_result).__name__}\")) if _helper_result_generator else None\n    (_ for _ in ()).throw(TypeError(f\"hddid_clime_requires_scipy() must return synchronously, got async generator {type(_helper_result).__name__}\")) if _helper_result_asyncgen else None\n    (_ for _ in ()).throw(TypeError(f\"hddid_clime_requires_scipy() must return synchronously, got awaitable {type(_helper_result).__name__}\")) if _helper_result_awaitable else None\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_nonbool\") if not isinstance(_helper_result, (bool, _np.bool_)) else None\nexcept ImportError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_importerror\")\nexcept OSError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_oserror\")\nexcept AttributeError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_attributeerror\")\nexcept ValueError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_valueerror\")\nexcept TypeError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_typeerror\")\nexcept RuntimeError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_runtimeerror\")\nexcept Exception:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_exception\")\nelse:\n    Macro.setLocal(\"_hddid_probe_reason\", Macro.getLocal(\"_hddid_probe_reason\") or \"ok\")") if Macro.getLocal("_hddid_probe_reason") == "" else None
        if _rc == 0 & "`_hddid_probe_reason'" != "" {
            return local reason "`_hddid_probe_reason'"
            exit
        }
        return local reason "helper_exception"
        exit
    }
    return local reason "`_hddid_probe_reason'"
end

capture program drop _hddid_prepare_fold_covinv
program define _hddid_prepare_fold_covinv, rclass
    version 16
    syntax , P(integer) FOLD(integer) TILDEX(name) COVINV(name) ///
        SEED(integer) NVALID(integer) CLIMEMAX(integer) ///
        CLIMENLAMBDA(integer) CLIMELAMBDAMINRATIO(real) ///
        PYSCRIPT(string asis) PYMODULE(string asis) ///
        PYHELPER(string asis) PYHASVERB(string asis) ///
        SCIPYVALIDATED(integer) [SUBCMDPREFIX(string asis) VERBOSE]
    local _k `fold'
    local __hddid_tildex `tildex'
    local __hddid_covinv_target `covinv'
    tempname __hddid_covinv
    local _n_valid `nvalid'
    local clime_nfolds_cv_requested `climemax'
    local clime_nlambda_requested `climenlambda'
    local clime_lambda_min_ratio `climelambdaminratio'
    local _hddid_pyscript `pyscript'
    local _hddid_py_module `pymodule'
    local _hddid_py_clime_helper_present `pyhelper'
    local _hddid_py_clime_hasverb `pyhasverb'
    local _hddid_scipy_validated `scipyvalidated'
    local _hddid_subcmd_prefix `subcmdprefix'
    if `p' > 1 {
        if `clime_nfolds_cv_requested' < 2 {
            di as error "{bf:hddid}: fold `_k' passed invalid CLIME CV tuning metadata"
            di as error "  climemax() = `clime_nfolds_cv_requested'"
            di as error "  Reason: retained-sample CLIME lambda selection uses cross-validation, so climemax() must be an integer >= 2 before any fold-size or Python-solver logic runs"
            exit 198
        }
        if missing(`clime_nlambda_requested') | `clime_nlambda_requested' < 1 {
            di as error "{bf:hddid}: fold `_k' passed invalid CLIME lambda-grid tuning metadata"
            di as error "  climenlambda() = `clime_nlambda_requested'"
            di as error "  Reason: retained-sample CLIME lambda selection needs at least one candidate lambda before any fold-size or Python-solver logic runs"
            exit 198
        }
        if missing(`clime_lambda_min_ratio') | ///
            `clime_lambda_min_ratio' <= 0 | ///
            `clime_lambda_min_ratio' > 1 {
            di as error "{bf:hddid}: fold `_k' passed invalid CLIME lambda-grid tuning metadata"
            di as error "  climelambdaminratio() = `clime_lambda_min_ratio'"
            di as error "  Reason: retained-sample CLIME lambda selection contracts the feasibility cap by a finite ratio in (0, 1], so the lambda-grid ratio must stay in that interval before any fold-size or Python-solver logic runs"
            exit 198
        }
    }
    tempname __hddid_tildex_nrows __hddid_tildex_ncols
    capture scalar drop `__hddid_tildex_nrows'
    capture scalar drop `__hddid_tildex_ncols'
    capture mata: st_numscalar("`__hddid_tildex_nrows'", ///
        rows(st_matrix("`__hddid_tildex'"))); ///
        st_numscalar("`__hddid_tildex_ncols'", ///
        cols(st_matrix("`__hddid_tildex'")))
    if _rc != 0 {
        di as error "{bf:hddid}: fold `_k' passed an invalid retained-sample tildex matrix contract"
        di as error "  Reason: the fold-level covariance helper could not recover rowsof(tildex) and colsof(tildex) before validating the retained-sample size metadata"
        exit 198
    }
    if scalar(`__hddid_tildex_nrows') != `_n_valid' {
        di as error "{bf:hddid}: fold `_k' reported inconsistent retained-sample size metadata"
        di as error "  nvalid() metadata = `_n_valid'"
        di as error "  rowsof(tildex)     = " %12.0f scalar(`__hddid_tildex_nrows')
        di as error "  Reason: the retained-sample covariance operator in equations (4.2) and the hddid-r precision path is defined by the actual retained tildex rows, so fold metadata must match the matrix passed to the helper"
        exit 198
    }
    if scalar(`__hddid_tildex_ncols') != `p' {
        di as error "{bf:hddid}: fold `_k' reported inconsistent retained-x dimension metadata"
        di as error "  p() metadata       = `p'"
        di as error "  colsof(tildex)     = " %12.0f scalar(`__hddid_tildex_ncols')
        di as error "  Reason: equations (4.2) and the hddid-r precision path define the retained-sample covariance inverse on the actual x-dimension of tildex, so p() must match the matrix passed to the helper before single-x versus CLIME branch selection"
        exit 198
    }
    if `p' == 1 & `_n_valid' < 1 {
        di as error "{bf:hddid}: fold `_k' has too few valid observations for the retained-sample covariance operator"
        di as error "  n_valid=`_n_valid'"
        di as error "  The retained single-x covariance in the beta-debias precision step requires at least 1 projected observation before the analytic scalar inverse can run"
        di as error "  Reason: for p=1, equation (4.2) targets the retained empirical second moment E_n[tildeX^2], so a positive scalar covariance object can already exist with one retained row"
        exit 2001
    }
    if `p' == 1 {
        tempname __hddid_singlex_second_moment __hddid_singlex_precision_probe
        capture scalar drop `__hddid_singlex_second_moment'
        capture scalar drop `__hddid_singlex_precision_probe'
        capture mata: __hddid_tildex_mat = st_matrix("`__hddid_tildex'"); ///
            __hddid_scale = max(abs(__hddid_tildex_mat)); ///
            __hddid_sigma = 0; ///
            __hddid_precision = .; ///
            if (__hddid_scale > 0 & __hddid_scale < .) { ///
                __hddid_tildex_mat = __hddid_tildex_mat :/ __hddid_scale; ///
                __hddid_sigma_scaled = ///
                    quadcross(__hddid_tildex_mat, __hddid_tildex_mat) / ///
                    rows(__hddid_tildex_mat); ///
                if (__hddid_sigma_scaled <= 0 | __hddid_sigma_scaled >= .) { ///
                    __hddid_sigma = __hddid_sigma_scaled; ///
                } ///
                else { ///
                    __hddid_precision = ///
                        ((1 / __hddid_sigma_scaled) * ///
                        (1 / __hddid_scale)) / ///
                        __hddid_scale; ///
                    __hddid_sigma_root = __hddid_scale * ///
                        sqrt(__hddid_sigma_scaled); ///
                    __hddid_sigma = __hddid_sigma_root^2; ///
                } ///
            }; ///
            st_numscalar("`__hddid_singlex_second_moment'", __hddid_sigma); ///
            st_numscalar("`__hddid_singlex_precision_probe'", __hddid_precision)
        if _rc != 0 {
            di as error "{bf:hddid}: fold `_k' passed an invalid retained single-x covariance contract"
            di as error "  Reason: the fold-level scalar precision helper could not recover a numerically stable analytic 1 / E_n[tildeX^2] contract from the retained tildex matrix"
            exit 198
        }
        if missing(scalar(`__hddid_singlex_precision_probe')) | ///
            scalar(`__hddid_singlex_precision_probe') <= 0 {
            if `_n_valid' == 1 {
                di as error "{bf:hddid}: fold `_k' has too few valid observations for the retained-sample covariance operator"
            }
            else {
                di as error "{bf:hddid}: fold `_k' has no positive retained single-x covariance object to invert"
            }
            di as error "  n_valid=`_n_valid'"
            di as error "  E_n[tildeX^2] = " %12.4e ///
                scalar(`__hddid_singlex_second_moment')
            di as error "  Reason: for p=1, equation (4.2) debiases beta with the inverse of the retained empirical second moment E_n[tildeX^2]"
            if `_n_valid' == 1 {
                di as error "  This singleton retained fold is only admissible when the retained scalar tildex row is nonzero after the sieve projection"
            }
            exit 2001
        }
    }
    if `p' > 1 & `_n_valid' < 2 {
        di as error "{bf:hddid}: fold `_k' has too few valid observations for the retained-sample covariance operator"
        di as error "  n_valid=`_n_valid'"
        di as error "  The retained-sample covariance in the multivariate beta-debias precision step requires at least 2 observations before the CLIME path can run"
        di as error "  Reason: with p>1 and fewer than 2 retained rows, the paper's retained-sample precision target cannot support a multivariate covariance inverse and the hddid-r sugm() path is likewise undefined"
        exit 2001
    }
        if `p' == 1 {
            // Keep the scalar path simple; there is no off-diagonal storage
            // mode to preserve when x() has only one column.
            matrix `__hddid_covinv' = J(1, 1, .)
            mata: st_matrix("`__hddid_covinv'", ///
                _hddid_single_x_precision(st_matrix("`__hddid_tildex'")))
            local _hddid_clime_effective = 0
            if "`verbose'" != "" {
                di as text "  Fold `_k': single-x precision uses the analytic scalar inverse; Python CLIME skipped"
            }
        }
        else if `p' < `_n_valid' {
            // When p < n_valid the retained-sample covariance is full-rank
            // and the analytic inverse luinv(Sigma_tildex) is well-defined.
            // Use it directly instead of the CLIME L1-regularized path, which
            // over-shrinks the precision matrix when Sigma is well-conditioned
            // (low p relative to n) and introduces systematic debiasing bias.
            // The CLIME path remains the default when p >= n_valid.
            matrix `__hddid_covinv' = J(`p', `p', .)
            capture mata: ///
                _pfc_tx = st_matrix("`__hddid_tildex'"); ///
                _pfc_n = rows(_pfc_tx); ///
                _pfc_Sig = cross(_pfc_tx, _pfc_tx) / _pfc_n; ///
                _pfc_cond = cond(_pfc_Sig); ///
                if (_pfc_cond < 1e10 & !hasmissing(_pfc_Sig)) { ///
                    _pfc_Om = luinv(_pfc_Sig); ///
                    if (!hasmissing(_pfc_Om)) { ///
                        st_matrix("`__hddid_covinv'", _pfc_Om); ///
                        st_local("_pfc_analytic_ok", "1"); ///
                    } ///
                    else { ///
                        st_local("_pfc_analytic_ok", "0"); ///
                    } ///
                } ///
                else { ///
                    st_local("_pfc_analytic_ok", "0"); ///
                }
            if _rc != 0 {
                local _pfc_analytic_ok "0"
            }
            if "`_pfc_analytic_ok'" == "1" {
                local _hddid_clime_effective = 0
                if "`verbose'" != "" {
                    di as text "  Fold `_k': p<n analytic inverse used; CLIME skipped (p=`p', n_valid=`_n_valid')"
                }
            }
            else {
                // Analytic inverse failed (ill-conditioned); fall through to CLIME
                if "`verbose'" != "" {
                    di as text "  Fold `_k': analytic inverse ill-conditioned; falling through to CLIME"
                }
                matrix `__hddid_covinv' = J(`p', `p', .)
                matrix `__hddid_covinv'[1, 2] = .a
            }
        }
        if "`_pfc_analytic_ok'" != "1" & `p' > 1 {
            // Stata stores J(p,p,.) as a symmetric matrix slot. Seed the
            // placeholder with asymmetric missing sentinels so malformed Python
            // writes cannot be silently coerced to symmetry before validation.
            matrix `__hddid_covinv' = J(`p', `p', .)
            matrix `__hddid_covinv'[1, 2] = .a
            local _hddid_clime_needs_scipy 0
            if "`_hddid_py_clime_helper_present'" == "1" {
                capture quietly _hddid_pfc_clime_scipy_probe, ///
                    script("`_hddid_pyscript'") ///
                    module("`_hddid_py_module'") ///
                    tildex(`__hddid_tildex')
                if _rc != 0 {
                    local _hddid_probe_reason "helper_nonbool"
                    capture quietly _hddid_pfc_probe_fail_classify, ///
                        script("`_hddid_pyscript'") ///
                        module("`_hddid_py_module'") ///
                        tildex(`__hddid_tildex')
                    if _rc == 0 & "`r(reason)'" != "" {
                        local _hddid_probe_reason `"`r(reason)'"'
                    }
                    if inlist("`_hddid_probe_reason'", "helper_exception", "helper_importerror", "helper_oserror", "helper_attributeerror", "helper_valueerror", "helper_typeerror", "helper_runtimeerror") {
                        capture noisily python: import functools, inspect, pathlib, sys; _module_path = pathlib.Path(r"`_hddid_pyscript'").resolve(); _module_name = r"`_hddid_py_module'"; _probe_name = "__hddid_probe__" + _module_name; _main_module = sys.modules.get(_module_name); _probe_module = sys.modules.get(_probe_name); _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; _module = _main_module if _main_ok else (_probe_module if _probe_ok else None); _helper = getattr(_module, "hddid_clime_requires_scipy", None) if _module is not None else None; _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; _helper_positional = []; _helper_kwargs = {'perturb': True}; exec("try:\n    _helper_sig_target = _helper\n    _prefer_object_sig = isinstance(_helper, functools.partial)\n    if _prefer_object_sig:\n        _helper_partial_func = _helper.func\n        _helper_partial_call = getattr(_helper_partial_func, \"__call__\", None)\n        if _helper_partial_call is not None and _helper_partial_call is not _helper_partial_func and not (inspect.isfunction(_helper_partial_func) or inspect.ismethod(_helper_partial_func) or inspect.isbuiltin(_helper_partial_func) or inspect.isroutine(_helper_partial_func)):\n            try:\n                _helper_sig_target = functools.partial(_helper_partial_call, *(_helper.args or ()), **(_helper.keywords or {}))\n                _prefer_object_sig = False\n            except TypeError:\n                _helper_sig_target = _helper\n                _prefer_object_sig = True\n    if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n        _helper_sig_target = _helper_call\n    _helper_sig = ((_module._resolve_bridge_signature(_helper)) or inspect.signature(_helper_sig_target, follow_wrapped=False)) if callable(getattr(_module, \"_resolve_bridge_signature\", None)) else inspect.signature(_helper_sig_target, follow_wrapped=False)\nexcept Exception:\n    pass\nelse:\n    _helper_params = _helper_sig.parameters\n    _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_params.values())\n    for _p in _helper_params.values():\n        if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n            _helper_positional.append(_helper_kwargs.pop(_p.name))\n    if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n        _helper_positional.append(_helper_kwargs.pop('perturb'))") if _helper is not None else None; (_helper("`__hddid_tildex'", *_helper_positional, **_helper_kwargs) if _helper is not None else None)
                    }
                    di as error "{bf:hddid}: CLIME sidecar failed the retained-sample SciPy-dependency probe in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    if "`_hddid_probe_reason'" == "cache_missing" {
                        di as error "  Reason: the loaded sidecar disappeared from Python's module cache before the retained-sample dependency probe ran"
                    }
                    else if "`_hddid_probe_reason'" == "helper_missing" {
                        di as error "  Reason: the loaded sidecar no longer exposes the required {bf:hddid_clime_requires_scipy()} helper"
                    }
                    else if "`_hddid_probe_reason'" == "helper_noncallable" {
                        di as error "  Reason: the loaded sidecar no longer exposes a callable {bf:hddid_clime_requires_scipy()} helper"
                    }
                    else if "`_hddid_probe_reason'" == "helper_valueerror" {
                        di as error "  Reason: the loaded sidecar rejected the retained tildex matrix before any SciPy decision"
                        di as error "  This is a retained-sample data/input validation failure, not a missing-dependency failure"
                    }
                    else if "`_hddid_probe_reason'" == "helper_importerror" {
                        di as error "  Reason: the loaded sidecar's {bf:hddid_clime_requires_scipy()} helper raised ImportError before returning any SciPy decision"
                        di as error "  This is a retained-sample dependency failure, not a retained-sample data/input validation failure"
                    }
                    else if "`_hddid_probe_reason'" == "helper_oserror" {
                        di as error "  Reason: the loaded sidecar's {bf:hddid_clime_requires_scipy()} helper raised OSError before returning any SciPy decision"
                        di as error "  This is a retained-sample host/file runtime failure, not a retained-sample dependency failure"
                    }
                    else if "`_hddid_probe_reason'" == "helper_attributeerror" {
                        di as error "  Reason: the loaded sidecar's {bf:hddid_clime_requires_scipy()} helper raised AttributeError before returning any SciPy decision"
                        di as error "  This is a retained-sample helper/runtime contract failure, not a retained-sample data/input validation failure"
                    }
                    else if "`_hddid_probe_reason'" == "helper_typeerror" {
                        di as error "  Reason: the loaded sidecar's {bf:hddid_clime_requires_scipy()} helper raised TypeError before returning any SciPy decision"
                        di as error "  This is a retained-sample helper contract failure, not a retained-sample data/input validation failure"
                    }
                    else if "`_hddid_probe_reason'" == "helper_runtimeerror" {
                        di as error "  Reason: the loaded sidecar's {bf:hddid_clime_requires_scipy()} helper raised RuntimeError before returning any SciPy decision"
                        di as error "  This is a retained-sample helper/runtime failure, not a retained-sample data/input validation failure"
                    }
                    else if "`_hddid_probe_reason'" == "helper_exception" {
                        di as error "  Reason: the loaded sidecar's {bf:hddid_clime_requires_scipy()} helper raised an exception before returning a dependency decision"
                    }
                    else {
                        di as error "  Reason: before checking SciPy, hddid asks the loaded sidecar whether the retained tildex matrix requires the SciPy LP path"
                        di as error "  The helper {bf:hddid_clime_requires_scipy()} must return a bool; truthy strings or arrays are invalid"
                    }
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                local _hddid_clime_needs_scipy `"`r(needs_scipy)'"'
            }
            if "`_hddid_clime_needs_scipy'" == "1" & `_hddid_scipy_validated' == 0 {
                // Python dependency versions may carry prerelease/local suffixes
                // such as 1.10rc1 or 2.0+cpu. Compare only the leading numeric
                // major/minor release fields before first non-diagonal CLIME use.
                local _hddid_scipy_ver ""
                local _hddid_scipy_ok 0
                local _hddid_scipy_highs_ok 0
                local _hsci_rth_p 0
                local _hsci_rth_c 0
                local _hsci_rth_t ""
                local _hsci_rth_u 0
                capture python: ///
                from sfi import Macro; import functools, inspect, pathlib, sys; ///
                    _module_path = pathlib.Path(r"`_hddid_pyscript'").resolve(); ///
                    _module_name = r"`_hddid_py_module'"; ///
                    _probe_name = "__hddid_probe__" + _module_name; ///
                    _main_module = sys.modules.get(_module_name); ///
                    _probe_module = sys.modules.get(_probe_name); ///
                    _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
                    _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
                    _module = _main_module if _main_ok else (_probe_module if _probe_ok else None); ///
                    _helper = getattr(_module, "hddid_clime_validate_solver_runtime", None) if _module is not None else None; ///
                    _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
                    _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
                    _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
                    _helper_sync = bool(_helper is not None and callable(_helper) and not _helper_async); ///
                    Macro.setLocal("_hsci_rth_p", str(1 if _helper is not None else 0)); ///
                    Macro.setLocal("_hsci_rth_c", str(1 if _helper_sync else 0)); ///
                    Macro.setLocal("_hsci_rth_t", ("async generator function" if _helper_asyncgen else ("async function" if _helper_async else type(_helper).__name__)) if _helper is not None else "")
                if "`_hsci_rth_p'" == "1" & "`_hsci_rth_c'" == "1" {
                    capture python: ///
                        from sfi import Macro; import inspect, pathlib, sys; ///
                        _module_path = pathlib.Path(r"`_hddid_pyscript'").resolve(); ///
                        _module_name = r"`_hddid_py_module'"; ///
                        _probe_name = "__hddid_probe__" + _module_name; ///
                        _main_module = sys.modules.get(_module_name); ///
                        _probe_module = sys.modules.get(_probe_name); ///
                        _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
                        _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
                        _module = _main_module if _main_ok else (_probe_module if _probe_ok else None); ///
                        _helper = getattr(_module, "hddid_clime_validate_solver_runtime"); ///
                        _result = _helper(); ///
                        _result_generator = bool(inspect.isgenerator(_result)); ///
                        _result_asyncgen = bool(inspect.isasyncgen(_result)) if not _result_generator else False; ///
                        _result_awaitable = bool(inspect.isawaitable(_result)) if not _result_generator and not _result_asyncgen else False; ///
                        _result_kind = ("generator " + type(_result).__name__) if _result_generator else (("async generator " + type(_result).__name__) if _result_asyncgen else ("awaitable " + type(_result).__name__)); ///
                        _result_close = getattr(_result, "close", None) if _result_generator else (getattr(_result, "aclose", None) if _result_asyncgen else (getattr(_result, "close", None) if _result_awaitable else None)); ///
                        _result_close_ret = _result_close() if callable(_result_close) else None; ///
                        _result_close_ret_close = getattr(_result_close_ret, "close", None) if _result_asyncgen else None; ///
                        _result_close_ret_close() if callable(_result_close_ret_close) else None; ///
                        (_ for _ in ()).throw(TypeError(f"hddid_clime_validate_solver_runtime() must return synchronously, got {_result_kind}")) if (_result_generator or _result_asyncgen or _result_awaitable) else None; ///
                        Macro.setLocal("_hsci_rth_u", "1")
                }
                if "`_hsci_rth_p'" == "1" & ///
                    "`_hsci_rth_c'" != "1" {
                    di as error "{bf:hddid}: loaded {bf:hddid_clime.py} exposes a non-callable {bf:hddid_clime_validate_solver_runtime()} helper"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  The helper type was {bf:`_hsci_rth_t'} rather than a callable runtime dependency probe"
                    di as error "  Reason: before rejecting a non-diagonal retained-sample CLIME fold for missing SciPy, hddid asks the loaded sidecar to validate the authoritative runtime LP solver contract"
                    di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
                    exit 198
                }
                if "`_hsci_rth_p'" == "1" & ///
                    "`_hsci_rth_c'" == "1" {
                    if _rc == 0 & "`_hsci_rth_u'" == "1" {
                        local _hddid_scipy_ok 1
                        local _hddid_scipy_highs_ok 1
                    }
                    else {
                        di as error "{bf:hddid}: loaded {bf:hddid_clime.py} failed inside {bf:hddid_clime_validate_solver_runtime()}"
                        di as error "  File loaded from: `_hddid_pyscript'"
                        di as error "  authoritative runtime LP solver contract failure."
                        di as error "  Reason: before rejecting a non-diagonal retained-sample CLIME fold for missing SciPy, hddid asks the loaded sidecar to validate the authoritative runtime LP solver contract"
                        di as error "  The helper {bf:hddid_clime_validate_solver_runtime()} raised an exception instead of returning a successful runtime verdict"
                        di as error "  This is an authoritative retained-sample dependency/runtime-helper failure, not a generic raw SciPy fallback"
                        di as error "  Check the Python error message above for details"
                        exit 198
                    }
                }
                else {
                    // The standalone fallback runs after the target sidecar has
                    // already been imported into Stata's persistent embedded
                    // Python session. Refresh SciPy's solver modules, but do
                    // not evict numpy underneath the loaded sidecar module:
                    // reloading numpy here can split the raw linprog probe and
                    // the active runtime bridge across incompatible module
                    // identities before fold execution. Also mirror the actual
                    // CLIME solve contract: _solve_clime_column() relies on the
                    // solver's default nonnegative box and does not pass an
                    // explicit bounds= keyword, so the fallback probe must not
                    // validate a different call shape than the real solve path.
                    quietly _hddid_pfc_uncache_scipy
                    local _hddid_scipy_highs_ok 0
                    capture python: ///
                        from sfi import Macro; import re; import numpy as _np; ///
                        import scipy; from scipy.optimize import linprog; ///
                        _ver = str(getattr(scipy, "__version__", "")); ///
                        _m = re.match(r"^\s*(\d+)\.(\d+)", _ver); ///
                        _probe = linprog(c=[1.0], A_ub=[[1.0]], b_ub=[1.0], ///
                            method="highs"); ///
                        _required = ("success", "status", "message", "x"); ///
                        (_ for _ in ()).throw(TypeError(f"scipy.optimize.linprog(method='highs') returned {type(_probe).__name__} without required OptimizeResult fields {_required}")) if any(not hasattr(_probe, _attr) for _attr in _required) else None; ///
                        _succ = getattr(_probe, "success"); ///
                        (_ for _ in ()).throw(TypeError("scipy.optimize.linprog(method='highs') returned an OptimizeResult.success payload without the required bool contract")) if not isinstance(_succ, (bool, _np.bool_)) else None; ///
                        _status = getattr(_probe, "status"); ///
                        (_ for _ in ()).throw(TypeError("scipy.optimize.linprog(method='highs') returned an OptimizeResult.status payload without the required integer contract")) if isinstance(_status, (bool, _np.bool_)) or not isinstance(_status, (int, _np.integer)) else None; ///
                        _message = getattr(_probe, "message"); ///
                        (_ for _ in ()).throw(TypeError("scipy.optimize.linprog(method='highs') returned an OptimizeResult.message payload without the required string contract")) if not isinstance(_message, str) else None; ///
                        (_ for _ in ()).throw(RuntimeError("scipy.optimize.linprog(method='highs') reported success=False on a trivial feasible probe")) if not bool(_succ) else None; ///
                        _x = _np.asarray(getattr(_probe, "x"), dtype=_np.float64); ///
                        (_ for _ in ()).throw(TypeError("scipy.optimize.linprog(method='highs') returned an OptimizeResult.x payload without the required finite length-1 numeric vector contract")) if _x.ndim != 1 or _x.size != 1 or not _np.isfinite(_x).all() else None; ///
                        Macro.setLocal("_hddid_scipy_ver", _ver); ///
                        Macro.setLocal("_hddid_scipy_ok", ///
                            str(int(_m is not None and ///
                            (int(_m.group(1)), int(_m.group(2))) >= (1, 7)))); ///
                        Macro.setLocal("_hddid_scipy_highs_ok", "1")
                }
                if _rc != 0 | "`_hddid_scipy_highs_ok'" != "1" {
                    di as error "{bf:hddid} requires the Python {bf:scipy} package (version >= 1.7) with {bf:scipy.optimize.linprog}"
                    di as error `"  Reason: at least one retained-sample CLIME fold is non-diagonal, so hddid must call {bf:scipy.optimize.linprog(method='highs')} and read its OptimizeResult fields"'
                    di as error "  The loaded sidecar's retained-sample dependency probe already confirmed that this fold needs the SciPy CLIME LP path"
                    di as error "  To install or repair: {bf:pip install --upgrade scipy>=1.7}"
                    exit 198
                }
                if "`_hddid_scipy_ok'" != "1" {
                    di as error "{bf:hddid} requires {bf:scipy} version 1.7 or later"
                    di as error "  Reason: {bf:scipy.optimize.linprog(method='highs')} requires scipy >= 1.7 on non-diagonal CLIME folds"
                    di as error "  Your scipy version: `_hddid_scipy_ver'"
                    di as error "  To upgrade: {bf:pip install --upgrade scipy}"
                    exit 198
                }
                local _hddid_scipy_validated 1
            }
            local _clime_nfolds_cv = floor(`_n_valid' / 2)
            if `_clime_nfolds_cv' > `clime_nfolds_cv_requested' {
                local _clime_nfolds_cv = `clime_nfolds_cv_requested'
            }
            local _hddid_skip_cv_guard 0
            if `_clime_nfolds_cv' < 2 & ///
                !("`_hddid_py_clime_helper_present'" == "1" & ///
                  "`_hddid_clime_needs_scipy'" == "1") {
                tempname __hddid_rawdiag_nsmall_ok
                tempname __hddid_rawdiag_nsmall_gap
                tempname __hddid_rawdiag_nsmall_tol
                capture scalar drop `__hddid_rawdiag_nsmall_ok'
                capture scalar drop `__hddid_rawdiag_nsmall_gap'
                capture scalar drop `__hddid_rawdiag_nsmall_tol'
                capture mata: X = st_matrix("`__hddid_tildex'"); ///
                    n = rows(X); ///
                    rawdiag_ok = 0; ///
                    diag_gap = .; ///
                    diag_tol = 64 * epsilon(1); ///
                    if (n >= 1) { ///
                        col_scale = colmax(abs(X)); ///
                        if (min(col_scale) > 0 & max(col_scale) < .) { ///
                            Xs = X :/ (J(n, 1, 1) * col_scale); ///
                            Sigma0 = quadcross(Xs, Xs) / n; ///
                            sigma_diag = diagonal(Sigma0); ///
                            offdiag = Sigma0 - diag(diagonal(Sigma0)); ///
                            pair_scale = sqrt(abs(sigma_diag * sigma_diag')); ///
                            pair_scale = pair_scale + (pair_scale :== 0); ///
                            diag_gap = max(abs(offdiag) :/ pair_scale); ///
                            omega_diag = J(rows(sigma_diag), 1, .); ///
                            if (min(sigma_diag) > 0) { ///
                                omega_diag = 1 :/ sigma_diag; ///
                                omega_diag = (omega_diag :/ col_scale') :/ col_scale'; ///
                            } ///
                            if (!hasmissing(omega_diag) & ///
                                min(omega_diag) > 0 & ///
                                diag_gap <= diag_tol) { ///
                                rawdiag_ok = 1; ///
                            } ///
                        } ///
                    }; ///
                    st_numscalar("`__hddid_rawdiag_nsmall_ok'", rawdiag_ok); ///
                    st_numscalar("`__hddid_rawdiag_nsmall_gap'", diag_gap); ///
                    st_numscalar("`__hddid_rawdiag_nsmall_tol'", diag_tol)
                if _rc == 0 & scalar(`__hddid_rawdiag_nsmall_ok') == 1 {
                    local _hddid_skip_cv_guard 1
                }
            }
            if `_clime_nfolds_cv' < 2 & `_hddid_skip_cv_guard' == 0 {
                // For p>1 the current shipped paper/R contract still uses the
                // CLIME+CV path unless the retained raw second moment already
                // defines the exact diagonal no-CV operator. Unless the helper
                // explicitly says SciPy is still required, the solve-time
                // operator contract itself gets the final say after the bridge
                // returns.
            }
            if `_clime_nfolds_cv' < 2 & `_hddid_skip_cv_guard' == 0 {
                di as error "{bf:hddid}: fold `_k' has too few valid observations for CLIME CV"
                di as error "  n_valid=`_n_valid', requested nfolds_cv=`clime_nfolds_cv_requested'"
                di as error "  CLIME CV requires at least 2 observations per validation fold under equal-block splitting"
                di as error "  This requires n_valid >= 4 before CLIME tuning can proceed"
                exit 2001
            }
            if "`verbose'" != "" & ///
                `_hddid_skip_cv_guard' == 0 & ///
                `_clime_nfolds_cv' < `clime_nfolds_cv_requested' {
                di as text "  Fold `_k': CLIME CV folds reduced from `clime_nfolds_cv_requested' to `_clime_nfolds_cv' to avoid singleton validation folds"
            }
            // Keep Python CLIME CV on the same RNG contract as the rest of hddid:
            // explicit seed() must advance the one seeded internal stream
            // rather than restarting the same Python seed in every fold, while
            // omitted seed() still derives a deterministic ambient-RNG-based
            // integer without consuming the bootstrap stream that seed(-1)
            // promises to preserve.
            local _clime_random_state `seed'
            if `seed' >= 0 {
                tempname __hddid_clime_seed_draw
                capture scalar drop `__hddid_clime_seed_draw'
                capture _hddid_pfc_run_rng_isolated `seed' ///
                    quietly scalar `__hddid_clime_seed_draw' = ///
                    floor(runiform() * 2147483647)
                if _rc != 0 {
                    di as error "{bf:hddid}: failed to derive a seeded Python CLIME random_state in fold `_k'"
                    di as error "  Reason: explicit seed() must advance the same internal RNG stream across Stata and Python stochastic substeps"
                    exit _rc
                }
                local _clime_random_state = scalar(`__hddid_clime_seed_draw')
                capture scalar drop `__hddid_clime_seed_draw'
            }
            else {
                local _clime_rngstate_before `c(rngstate)'
                local _clime_random_state = floor(runiform() * 2147483647)
                quietly set rngstate `_clime_rngstate_before'
                local _clime_random_state = mod(`_clime_random_state' + `_k' - 1, 2147483647)
            }
            local _clime_verbose False
            if "`verbose'" != "" {
            local _clime_verbose True
        }
            local _hddid_clime_verbose_kw ""
            if "`verbose'" != "" {
                local _hddid_clime_verbose_kw ", 'verbose': `_clime_verbose'"
            }
            local _hddid_clime_restore_scalar 0
            local _hddid_clime_restore_raw_scalar 0
            local _hddid_clime_raw_feasible 0
            tempname __hddid_clime_prior
            tempname __hddid_clime_raw_prior
            capture confirm scalar __hddid_clime_effective_nfolds
            if _rc == 0 {
                scalar `__hddid_clime_prior' = ///
                    scalar(__hddid_clime_effective_nfolds)
                local _hddid_clime_restore_scalar 1
            }
            capture confirm scalar __hddid_clime_raw_feasible
            if _rc == 0 {
                scalar `__hddid_clime_raw_prior' = ///
                    scalar(__hddid_clime_raw_feasible)
                local _hddid_clime_restore_raw_scalar 1
            }
            capture scalar drop __hddid_clime_effective_nfolds
            capture scalar drop __hddid_clime_raw_feasible
            local _hddid_clime_call_reason ""
            capture `_hddid_subcmd_prefix' python: ///
                from sfi import Macro; import functools, importlib.util, inspect, pathlib, sys; ///
                import hashlib; ///
                _module_path = pathlib.Path(r"`_hddid_pyscript'").resolve(); ///
                _module_name = r"`_hddid_py_module'"; ///
                _probe_name = "__hddid_probe__" + _module_name; ///
                _main_module = sys.modules.get(_module_name); ///
                _probe_module = sys.modules.get(_probe_name); ///
                _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
                _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
                _module = _main_module if _main_ok else (_probe_module if _probe_ok else (_main_module if _main_module is not None else _probe_module)); ///
                _cache_ok = _main_ok or _probe_ok; ///
                Macro.setLocal("_hddid_clime_call_reason", ""); ///
                _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
                _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
                _probe_only = bool(getattr(_module, "_hddid_safe_probe_only", 0)) if _module is not None else False; ///
                exec("try:\n    if (not _cache_ok) or _probe_only or _cached_hash != _source_hash:\n        _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n        if _reload_spec is None or _reload_spec.loader is None:\n            raise ImportError(f'Unable to create import spec for {_module_path}')\n        _full_module = importlib.util.module_from_spec(_reload_spec)\n        exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n        setattr(_full_module, '_hddid_safe_probe_only', 0)\n        setattr(_full_module, '_hddid_source_hash', _source_hash)\n        sys.modules[_module_name] = _full_module\n        sys.modules.pop(_probe_name, None)\n        _module = _full_module\n        _cached_hash = _source_hash\n        _cache_ok = True\n        _probe_only = False\nexcept ImportError:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_importerror')\n    raise\nexcept OSError:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_oserror')\n    raise\nexcept AttributeError:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_attributeerror')\n    raise\nexcept ValueError:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_valueerror')\n    raise\nexcept TypeError:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_typeerror')\n    raise\nexcept RuntimeError:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_runtimeerror')\n    raise\nexcept SyntaxError:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_syntaxerror')\n    raise\nexcept Exception:\n    Macro.setLocal('_hddid_clime_call_reason', 'load_exception')\n    raise"); ///
                _bridge = None if Macro.getLocal("_hddid_clime_call_reason") != "" else getattr(_module, "_hddid_bridge_call_clime_solve", None); ///
                _bridge_async = bool(_bridge is not None and (inspect.iscoroutinefunction(_bridge) or inspect.isasyncgenfunction(_bridge) or inspect.iscoroutinefunction(getattr(_bridge, "__call__", None)) or inspect.isasyncgenfunction(getattr(_bridge, "__call__", None)))); ///
                Macro.setLocal("_hddid_clime_call_reason", "bridge_noncallable" if Macro.getLocal("_hddid_clime_call_reason") == "" and _bridge is not None and (not callable(_bridge) or _bridge_async) else Macro.getLocal("_hddid_clime_call_reason")); ///
                (_ for _ in ()).throw(TypeError(f"_hddid_bridge_call_clime_solve must be a synchronous callable, got {'async generator function' if inspect.isasyncgenfunction(_bridge) or inspect.isasyncgenfunction(getattr(_bridge, '__call__', None)) else 'async function'}")) if Macro.getLocal("_hddid_clime_call_reason") == "bridge_noncallable" and _bridge_async else None; ///
                (_ for _ in ()).throw(TypeError(f"_hddid_bridge_call_clime_solve must be callable, got {type(_bridge).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "bridge_noncallable" and not _bridge_async else None; ///
                _obj = None if Macro.getLocal("_hddid_clime_call_reason") != "" else (_bridge if callable(_bridge) else (None if _probe_only else getattr(_module, "hddid_clime_solve", None))); ///
                _obj_call = getattr(_obj, "__call__", None) if Macro.getLocal("_hddid_clime_call_reason") == "" and _obj is not None else None; ///
                _obj_async = bool(_obj is not None and (inspect.iscoroutinefunction(_obj) or inspect.isasyncgenfunction(_obj) or inspect.iscoroutinefunction(_obj_call) or inspect.isasyncgenfunction(_obj_call))) if Macro.getLocal("_hddid_clime_call_reason") == "" else False; ///
                Macro.setLocal("_hddid_clime_call_reason", "solve_missing" if Macro.getLocal("_hddid_clime_call_reason") == "" and _obj is None else Macro.getLocal("_hddid_clime_call_reason")); ///
                Macro.setLocal("_hddid_clime_call_reason", "solve_noncallable" if Macro.getLocal("_hddid_clime_call_reason") == "" and _obj is not None and not callable(_obj) else Macro.getLocal("_hddid_clime_call_reason")); ///
                Macro.setLocal("_hddid_clime_call_reason", "solve_typeerror" if Macro.getLocal("_hddid_clime_call_reason") == "" and _obj_async else Macro.getLocal("_hddid_clime_call_reason")); ///
                (_ for _ in ()).throw(AttributeError("hddid_clime_solve entry point missing")) if Macro.getLocal("_hddid_clime_call_reason") == "solve_missing" else None; ///
                (_ for _ in ()).throw(TypeError(f"hddid_clime_solve must be callable, got {type(_obj).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "solve_noncallable" else None; ///
                (_ for _ in ()).throw(TypeError(f"hddid_clime_solve must be a synchronous callable, got {'async generator function' if inspect.isasyncgenfunction(_obj) or inspect.isasyncgenfunction(_obj_call) else 'async function'}")) if Macro.getLocal("_hddid_clime_call_reason") == "solve_typeerror" and _obj_async else None; ///
                _solve_kwargs = {'nfolds_cv': `_clime_nfolds_cv', 'nlambda': `clime_nlambda_requested', 'lambda_min_ratio': `clime_lambda_min_ratio', 'random_state': `_clime_random_state', 'perturb': True, 'parallel': False, 'nproc': None`_hddid_clime_verbose_kw'} if Macro.getLocal("_hddid_clime_call_reason") == "" else None; ///
                _dispatch_bridge_call = getattr(_module, "_dispatch_bridge_runtime_call", None) if Macro.getLocal("_hddid_clime_call_reason") == "" else None; ///
                _filter_bridge_kwargs = getattr(_module, "_filter_bridge_optional_kwargs", None) if Macro.getLocal("_hddid_clime_call_reason") == "" else None; ///
                _bridge_tail_builder = getattr(_module, "_bridge_optional_tail_from_kwargs", None) if Macro.getLocal("_hddid_clime_call_reason") == "" else None; ///
                _retry_bridge_tail = getattr(_module, "_should_retry_bridge_positional_tail", None) if Macro.getLocal("_hddid_clime_call_reason") == "" else None; ///
                exec("try:\n    _obj_result = _dispatch_bridge_call(_obj, r'`__hddid_tildex'', r'`__hddid_covinv'', _solve_kwargs)\nexcept TypeError as _dispatch_exc:\n    _retry_needed = callable(_retry_bridge_tail) and _retry_bridge_tail(_dispatch_exc)\n    if not _retry_needed:\n        raise\n    _solve_args = ()\n    _solve_call_kwargs = dict(_solve_kwargs)\n    if callable(_filter_bridge_kwargs):\n        _solve_args, _solve_call_kwargs = _filter_bridge_kwargs(_obj, dict(_solve_kwargs))\n    try:\n        _obj_result = _obj(r'`__hddid_tildex'', r'`__hddid_covinv'', *_solve_args, **_solve_call_kwargs)\n    except TypeError as _solve_exc:\n        _retry_needed = callable(_retry_bridge_tail) and _retry_bridge_tail(_solve_exc)\n        if not _retry_needed:\n            raise\n        if callable(_bridge_tail_builder):\n            _retry_args = _bridge_tail_builder(_solve_call_kwargs)\n        else:\n            _retry_args = tuple(_solve_call_kwargs[_name] for _name in ('nfolds_cv', 'nlambda', 'lambda_min_ratio', 'perturb', 'parallel', 'nproc', 'random_state', 'verbose') if _name in _solve_call_kwargs)\n        if not _retry_args:\n            raise\n        _obj_result = _obj(r'`__hddid_tildex'', r'`__hddid_covinv'', *_retry_args)") if Macro.getLocal("_hddid_clime_call_reason") == "" and callable(_dispatch_bridge_call) else None; ///
                exec("try:\n    _solve_args = ()\n    _solve_call_kwargs = dict(_solve_kwargs)\n    if callable(_filter_bridge_kwargs):\n        _solve_args, _solve_call_kwargs = _filter_bridge_kwargs(_obj, dict(_solve_kwargs))\n    _obj_result = _obj(r'`__hddid_tildex'', r'`__hddid_covinv'', *_solve_args, **_solve_call_kwargs)\nexcept TypeError as _solve_exc:\n    _retry_needed = callable(_retry_bridge_tail) and _retry_bridge_tail(_solve_exc)\n    if not _retry_needed:\n        raise\n    if callable(_bridge_tail_builder):\n        _retry_args = _bridge_tail_builder(_solve_call_kwargs)\n    else:\n        _retry_args = tuple(_solve_call_kwargs[_name] for _name in ('nfolds_cv', 'nlambda', 'lambda_min_ratio', 'perturb', 'parallel', 'nproc', 'random_state', 'verbose') if _name in _solve_call_kwargs)\n    if not _retry_args:\n        raise\n    _obj_result = _obj(r'`__hddid_tildex'', r'`__hddid_covinv'', *_retry_args)") if Macro.getLocal("_hddid_clime_call_reason") == "" and not callable(_dispatch_bridge_call) else None; ///
                _obj_result_generator = bool(inspect.isgenerator(_obj_result)) if Macro.getLocal("_hddid_clime_call_reason") == "" else False; ///
                _obj_result_asyncgen = bool(inspect.isasyncgen(_obj_result)) if Macro.getLocal("_hddid_clime_call_reason") == "" and not _obj_result_generator else False; ///
                _obj_result_awaitable = bool(inspect.isawaitable(_obj_result)) if Macro.getLocal("_hddid_clime_call_reason") == "" and not _obj_result_generator and not _obj_result_asyncgen else False; ///
                _obj_result_close = getattr(_obj_result, "close", None) if _obj_result_generator else (getattr(_obj_result, "aclose", None) if _obj_result_asyncgen else (getattr(_obj_result, "close", None) if _obj_result_awaitable else None)); ///
                _obj_result_close_ret = _obj_result_close() if callable(_obj_result_close) else None; ///
                _obj_result_close_ret_close = getattr(_obj_result_close_ret, "close", None) if _obj_result_asyncgen else None; ///
                _obj_result_close_ret_close() if callable(_obj_result_close_ret_close) else None; ///
                Macro.setLocal("_hddid_clime_call_reason", "solve_typeerror" if Macro.getLocal("_hddid_clime_call_reason") == "" and _bridge is None and (_obj_result_generator or _obj_result_asyncgen or _obj_result_awaitable) else Macro.getLocal("_hddid_clime_call_reason")); ///
                Macro.setLocal("_hddid_clime_call_reason", "bridge_badresult" if Macro.getLocal("_hddid_clime_call_reason") == "" and (_bridge is not None and (_obj_result_generator or _obj_result_asyncgen or _obj_result_awaitable)) else Macro.getLocal("_hddid_clime_call_reason")); ///
                (_ for _ in ()).throw(TypeError(f"hddid_clime_solve must return synchronously, got generator {type(_obj_result).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "solve_typeerror" and _bridge is None and _obj_result_generator else None; ///
                (_ for _ in ()).throw(TypeError(f"hddid_clime_solve must return synchronously, got async generator {type(_obj_result).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "solve_typeerror" and _bridge is None and _obj_result_asyncgen else None; ///
                (_ for _ in ()).throw(TypeError(f"hddid_clime_solve must return synchronously, got awaitable {type(_obj_result).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "solve_typeerror" and _bridge is None and _obj_result_awaitable else None; ///
                (_ for _ in ()).throw(TypeError(f"_hddid_bridge_call_clime_solve must return synchronously, got generator {type(_obj_result).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "bridge_badresult" and _obj_result_generator else None; ///
                (_ for _ in ()).throw(TypeError(f"_hddid_bridge_call_clime_solve must return synchronously, got async generator {type(_obj_result).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "bridge_badresult" and _obj_result_asyncgen else None; ///
                (_ for _ in ()).throw(TypeError(f"_hddid_bridge_call_clime_solve must return synchronously, got awaitable {type(_obj_result).__name__}")) if Macro.getLocal("_hddid_clime_call_reason") == "bridge_badresult" and _obj_result_awaitable else None
            if _rc != 0 {
                if `_hddid_clime_restore_scalar' {
                    capture scalar drop __hddid_clime_effective_nfolds
                    scalar __hddid_clime_effective_nfolds = ///
                        scalar(`__hddid_clime_prior')
                }
                else {
                    capture scalar drop __hddid_clime_effective_nfolds
                }
                if `_hddid_clime_restore_raw_scalar' {
                    capture scalar drop __hddid_clime_raw_feasible
                    scalar __hddid_clime_raw_feasible = ///
                        scalar(`__hddid_clime_raw_prior')
                }
                else {
                    capture scalar drop __hddid_clime_raw_feasible
                }
                if "`_hddid_clime_call_reason'" == "" {
                    local _hddid_clime_call_reason "solve_exception"
                }
                if "`_hddid_clime_call_reason'" == "cache_missing" {
                    di as error "{bf:hddid}: CLIME sidecar disappeared from Python's module cache before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the cached sidecar module was no longer available at the retained-sample CLIME call boundary"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_missing" {
                    di as error "{bf:hddid}: loaded sidecar no longer exposes the required {bf:hddid_clime_solve()} entry point"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: hddid checks this bridge entry point before every retained-sample CLIME call because the debiasing step requires a precision matrix on every p>1 fold"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_noncallable" {
                    di as error "{bf:hddid}: loaded sidecar no longer exposes a callable {bf:hddid_clime_solve()} entry point"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: hddid checks this bridge entry point before every retained-sample CLIME call because the debiasing step requires a callable precision-matrix solver on every p>1 fold"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "bridge_noncallable" {
                    di as error "{bf:hddid}: loaded sidecar no longer exposes a callable {bf:_hddid_bridge_call_clime_solve()} runtime bridge"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the retained-sample CLIME bridge shim must stay callable through fold execution so hddid can classify solve-time contract failures before beta debiasing"
                    di as error "  This is a retained-sample solve contract failure, not a generic CLIME optimization failure"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "bridge_badresult" {
                    di as error "{bf:hddid}: loaded sidecar returned a non-synchronous {bf:_hddid_bridge_call_clime_solve()} runtime bridge result"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the retained-sample CLIME bridge shim must finish synchronously and publish the precision matrix plus realized fold metadata before beta debiasing"
                    di as error "  This is a retained-sample solve contract failure, not a missing-metadata follow-on failure"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_valueerror" {
                    di as error "{bf:hddid}: CLIME sidecar rejected a load-time bridge input before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised ValueError while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar load-time validation failure, not a retained-sample solve failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_typeerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a load-time TypeError before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised TypeError while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar load-time contract failure, not a retained-sample solve failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_runtimeerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a load-time RuntimeError before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised RuntimeError while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar load-time failure, not a retained-sample solve RuntimeError"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_oserror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a load-time OSError before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar hit a host/runtime failure while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar load-time host/runtime failure, not a dependency failure or a retained-sample solve failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_importerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a load-time dependency failure before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised ImportError while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar load-time dependency failure, not a retained-sample solve dependency failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_attributeerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a load-time AttributeError before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised AttributeError while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar load-time bridge contract failure, not a retained-sample solve failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_syntaxerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a load-time SyntaxError before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar could not be parsed while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar source-parse failure, not a retained-sample solve failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "load_exception" {
                    di as error "{bf:hddid}: CLIME sidecar hit a load-time exception before fold `_k' ran"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised an exception while reloading the full module body, before any retained-sample precision solve began"
                    di as error "  This is a sidecar load-time bridge failure, not a retained-sample solve failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_valueerror" {
                    di as error "{bf:hddid}: CLIME sidecar rejected the retained-sample solve inputs in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised ValueError before returning any precision matrix"
                    di as error "  This is a retained-sample solve input validation failure, not a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_typeerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a retained-sample solve TypeError in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised TypeError before returning any precision matrix"
                    di as error "  This is a retained-sample solve contract failure, not a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_runtime_contracterror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a retained-sample solve RuntimeError in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised RuntimeError before returning any precision matrix"
                    di as error "  This is a retained-sample solve runtime contract failure, not a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_runtimeerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a retained-sample solve RuntimeError in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised RuntimeError before returning any precision matrix"
                    di as error "  This is a retained-sample solve runtime failure, not a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_importerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a retained-sample solve dependency failure in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised ImportError before returning any precision matrix"
                    di as error "  This is a retained-sample solve dependency failure, not a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_oserror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a retained-sample solve OSError in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised OSError before returning any precision matrix"
                    di as error "  This is a retained-sample solve host/runtime failure, not a dependency failure or a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_attributeerror" {
                    di as error "{bf:hddid}: CLIME sidecar hit a retained-sample solve AttributeError in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised AttributeError before returning any precision matrix"
                    di as error "  This is a retained-sample solve contract failure, not a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                if "`_hddid_clime_call_reason'" == "solve_exception" {
                    di as error "{bf:hddid}: CLIME sidecar hit a retained-sample solve exception in fold `_k'"
                    di as error "  File loaded from: `_hddid_pyscript'"
                    di as error "  Reason: the loaded sidecar raised an exception before returning any precision matrix"
                    di as error "  This is a retained-sample solve bridge failure, not a generic CLIME optimization failure"
                    di as error "  Check the Python error message above for details"
                    exit 198
                }
                di as error "{bf:hddid}: CLIME precision matrix estimation failed in fold `_k'"
                di as error "  Check Python error message above for details"
                exit 198
            }
            capture confirm scalar __hddid_clime_effective_nfolds
            if _rc != 0 {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar did not report realized CV usage in fold `_k'"
                di as error "  The loaded hddid_clime.py is missing the __hddid_clime_effective_nfolds contract"
                di as error "  Please reinstall the hddid package"
                exit 198
            }
            capture confirm scalar __hddid_clime_raw_feasible
            if _rc == 0 {
                local _hddid_clime_raw_feasible = scalar(__hddid_clime_raw_feasible)
                if missing(`_hddid_clime_raw_feasible') | ///
                    `_hddid_clime_raw_feasible' != floor(`_hddid_clime_raw_feasible') | ///
                    !inlist(`_hddid_clime_raw_feasible', 0, 1) {
                    quietly _hddid_pfc_restore, ///
                        nfrestore(`_hddid_clime_restore_scalar') ///
                        rawrestore(`_hddid_clime_restore_raw_scalar') ///
                        nfprior(`__hddid_clime_prior') ///
                        rawprior(`__hddid_clime_raw_prior')
                    di as error "{bf:hddid}: CLIME sidecar reported an invalid raw-feasibility scalar contract in fold `_k'"
                    di as error "  The auxiliary scalar __hddid_clime_raw_feasible must be exactly 0 or 1 when present"
                    di as error "  Reason: the sidecar may certify that the raw unsymmetrized CLIME columns were feasible even when the published symmetric matrix is flare-style post-processed"
                    exit 198
                }
            }
            if `_hddid_clime_restore_raw_scalar' {
                capture scalar drop __hddid_clime_raw_feasible
                scalar __hddid_clime_raw_feasible = ///
                    scalar(`__hddid_clime_raw_prior')
            }
            else {
                capture scalar drop __hddid_clime_raw_feasible
            }
            local _clime_covinv_rows = rowsof(`__hddid_covinv')
            local _clime_covinv_cols = colsof(`__hddid_covinv')
            if `_clime_covinv_rows' != `p' | `_clime_covinv_cols' != `p' {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  expected `p' x `p', got `_clime_covinv_rows' x `_clime_covinv_cols'"
                di as error "  Reason: equations (4.2) and the parametric debias step require a square precision matrix matching x()"
                exit 198
            }
            tempname __hddid_covinv_contract_ok
            capture scalar drop `__hddid_covinv_contract_ok'
            capture mata: st_numscalar("`__hddid_covinv_contract_ok'", ///
                !hasmissing(st_matrix("`__hddid_covinv'")) & ///
                max(st_matrix("`__hddid_covinv'") :>= 8.98846567431158e307) == 0)
            if _rc != 0 | scalar(`__hddid_covinv_contract_ok') != 1 {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  The returned `p' x `p' matrix must be finite and must not contain Stata missing values"
                di as error "  The sidecar did not overwrite the preallocated output matrix; leaving placeholders behind is not a valid write-back"
                di as error "  Reason: parametric debiasing multiplies the retained-sample tildex by this precision matrix"
                exit 198
            }
            tempname __hddid_covinv_sym_gap __hddid_covinv_sym_tol
            capture scalar drop `__hddid_covinv_sym_gap'
            capture scalar drop `__hddid_covinv_sym_tol'
            capture mata: C = st_matrix("`__hddid_covinv'"); ///
                scale = max(abs(C)); ///
                if (scale <= 0 | scale >= .) scale = 1; ///
                st_numscalar("`__hddid_covinv_sym_gap'", ///
                max(abs(C :- C'))); ///
                st_numscalar("`__hddid_covinv_sym_tol'", ///
                1e-10 * scale)
            if _rc != 0 {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  Unable to verify the returned precision-matrix symmetry"
                di as error "  Reason: equations (4.2) and the parametric debias step require a covariance inverse in x() space"
                exit 198
            }
            if scalar(`__hddid_covinv_sym_gap') > scalar(`__hddid_covinv_sym_tol') {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  The returned `p' x `p' precision matrix must be symmetric within numerical tolerance"
                di as error "  max |Omega - Omega'| = " %12.4e scalar(`__hddid_covinv_sym_gap')
                di as error "  tolerance           = " %12.4e scalar(`__hddid_covinv_sym_tol')
                di as error "  Reason: the paper's debiasing step uses a covariance inverse, which is symmetric by construction"
                exit 198
            }
            tempname __hddid_covinv_diagshort
            tempname __hddid_covinv_rawdiagshort
            tempname __hddid_covinv_scaleop_ok
            tempname __hddid_covinv_rawscaleop_ok
            capture scalar drop `__hddid_covinv_diagshort'
            capture scalar drop `__hddid_covinv_rawdiagshort'
            capture scalar drop `__hddid_covinv_scaleop_ok'
            capture scalar drop `__hddid_covinv_rawscaleop_ok'
            // Section 4 / hddid-r consume the retained precision operator
            // directly. On exact diagonal retained folds, a finite analytic
            // Omega can remain usable even when reconstructing raw Sigma would
            // overflow in machine units. More generally, the bridge can also
            // certify a non-diagonal operator directly on a scale-stable
            // Sigma*Omega path without materializing the original-scale Sigma.
            // Some sidecars emit operators for the centered+rige surrogate,
            // while others certify the paper's raw retained second moment
            // E_n[tildeX*tildeX']. Accept either contract when its own
            // scale-stable Sigma*Omega identity is numerically accurate.
            capture mata: X = st_matrix("`__hddid_tildex'"); ///
                Omega = st_matrix("`__hddid_covinv'"); ///
                diag_shortcut = 0; ///
                rawdiag_shortcut = 0; ///
                scaleop_ok = 0; ///
                rawscaleop_ok = 0; ///
                n = rows(X); ///
                raw_feasible = `_hddid_clime_raw_feasible'; ///
                if (n > 1) { ///
                    Xc = X :- J(n, 1, 1) * mean(X); ///
                    x_scale = max(abs(Xc)); ///
                    if (x_scale > 0 & x_scale < .) { ///
                        inv_x_scale = 1 / x_scale; ///
                        inv_x_scale_sq = inv_x_scale / x_scale; ///
                        if (inv_x_scale_sq > 0 & inv_x_scale_sq < .) { ///
                            Xc = Xc :/ x_scale; ///
                            Sigma_scaled = quadcross(Xc, Xc) / n; ///
                            sigma_diag = diagonal(Sigma_scaled); ///
                            offdiag_scaled = Sigma_scaled - diag(diagonal(Sigma_scaled)); ///
                            pair_scale = sqrt(abs(sigma_diag * sigma_diag')); ///
                            pair_scale = pair_scale + (pair_scale :== 0); ///
                            diag_geom_gap = max(abs(offdiag_scaled) :/ pair_scale); ///
                            diag_geom_tol = 64 * epsilon(1); ///
                            omega_offdiag = Omega - diag(diagonal(Omega)); ///
                            omega_diag = diagonal(Omega); ///
                            omega_off_gap = max(abs(omega_offdiag)); ///
                            omega_off_tol = 1e-8 * max(abs(omega_diag)); ///
                            omega_oracle = J(rows(Omega), 1, inv_x_scale_sq) :/ ///
                                (sigma_diag + J(rows(Omega), 1, inv_x_scale_sq / sqrt(n))); ///
                            omega_gap = max(abs(omega_diag - omega_oracle)); ///
                            omega_tol = 1e-8 * max(abs(omega_oracle)); ///
                            if (!hasmissing(omega_oracle) & ///
                                min(omega_diag) > 0 & ///
                                diag_geom_gap <= diag_geom_tol & ///
                                omega_off_gap <= omega_off_tol & ///
                                omega_gap <= omega_tol) { ///
                                diag_shortcut = 1; ///
                            } ///
                            Omega_scaled = Omega * x_scale; ///
                            if (!hasmissing(Omega_scaled)) { ///
                                Omega_scaled = Omega_scaled * x_scale; ///
                            } ///
                            if (!hasmissing(Omega_scaled)) { ///
                                SigmaOmega = Sigma_scaled * Omega_scaled + ///
                                    (I(cols(X)) / sqrt(n)) * Omega; ///
                                scaleop_gap = max(abs(SigmaOmega - I(cols(X)))); ///
                                scaleop_tol = 1e-10 * ///
                                    max((1, max(abs(SigmaOmega)))) * cols(X); ///
                                if (scaleop_gap <= scaleop_tol) { ///
                                    scaleop_ok = 1; ///
                                } ///
                            } ///
                        } ///
                    }; ///
                    col_scale_raw = colmax(abs(X)); ///
                    if (min(col_scale_raw) > 0 & max(col_scale_raw) < .) { ///
                        Xraw = X :/ (J(n, 1, 1) * col_scale_raw); ///
                        Sigma_raw_scaled = quadcross(Xraw, Xraw) / n; ///
                        raw_sigma_diag = diagonal(Sigma_raw_scaled); ///
                        raw_offdiag = Sigma_raw_scaled - ///
                            diag(diagonal(Sigma_raw_scaled)); ///
                        raw_pair_scale = sqrt(abs(raw_sigma_diag * raw_sigma_diag')); ///
                        raw_pair_scale = raw_pair_scale + (raw_pair_scale :== 0); ///
                        raw_diag_gap = max(abs(raw_offdiag) :/ raw_pair_scale); ///
                        raw_diag_tol = 64 * epsilon(1); ///
                        Omega_raw_scaled = diag(col_scale_raw') * Omega * ///
                            diag(col_scale_raw'); ///
                        if (!hasmissing(Omega_raw_scaled)) { ///
                            SigmaOmega_raw = Sigma_raw_scaled * Omega_raw_scaled; ///
                            scaleop_gap_raw = max(abs(SigmaOmega_raw - I(cols(X)))); ///
                            scaleop_tol_raw = 1e-10 * ///
                                max((1, max(abs(SigmaOmega_raw)))) * cols(X); ///
                            if (raw_feasible == 1 & ///
                                raw_diag_gap <= raw_diag_tol & ///
                                scaleop_gap_raw <= scaleop_tol_raw) { ///
                                rawdiag_shortcut = 1; ///
                            } ///
                            /* Once the published raw retained operator ///
                               itself certifies Sigma_tildex * Omega = I, ///
                               paper equation (4.2) / hddid-r only need ///
                               that operator contract; solver provenance ///
                               metadata is no longer a mathematical ///
                               prerequisite for the zero-fold shortcut. */ ///
                            if (scaleop_gap_raw <= scaleop_tol_raw) { ///
                                rawscaleop_ok = 1; ///
                            } ///
                            if (scaleop_gap_raw <= scaleop_tol_raw) { ///
                                scaleop_ok = 1; ///
                            } ///
                        } ///
                    } ///
                }; ///
                st_numscalar("`__hddid_covinv_diagshort'", diag_shortcut); ///
                st_numscalar("`__hddid_covinv_rawdiagshort'", rawdiag_shortcut); ///
                st_numscalar("`__hddid_covinv_scaleop_ok'", scaleop_ok); ///
                st_numscalar("`__hddid_covinv_rawscaleop_ok'", rawscaleop_ok)
            if _rc != 0 {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  Unable to verify whether the returned precision matrix matches the exact diagonal retained-operator shortcut"
                di as error "  Reason: equation (4.2) allows a diagonal retained precision operator when its scale-stable analytic inverse remains finite"
                exit 198
            }
            tempname __hddid_covinv_min_sval __hddid_covinv_sval_tol
            tempname __hddid_covinv_inv_gap __hddid_covinv_inv_tol
            tempname __hddid_covinv_inv_ok
            capture scalar drop `__hddid_covinv_min_sval'
            capture scalar drop `__hddid_covinv_sval_tol'
            capture scalar drop `__hddid_covinv_inv_gap'
            capture scalar drop `__hddid_covinv_inv_tol'
            capture scalar drop `__hddid_covinv_inv_ok'
            capture mata: C = st_matrix("`__hddid_covinv'"); ///
                U = J(rows(C), rows(C), .); ///
                s = J(rows(C), 1, .); ///
                Vt = J(rows(C), rows(C), .); ///
                svd(C, U, s, Vt); ///
                sval_scale = max(s); ///
                if (sval_scale <= 0 | sval_scale >= .) sval_scale = 1; ///
                Cinv = luinv(C); ///
                if (hasmissing(Cinv) & min(s) > 0 & !hasmissing(s)) { ///
                    Cinv = Vt' * diag(1 :/ s) * U'; ///
                }; ///
                st_numscalar("`__hddid_covinv_min_sval'", min(s)); ///
                st_numscalar("`__hddid_covinv_sval_tol'", 1e-10 * sval_scale); ///
                st_numscalar("`__hddid_covinv_inv_ok'", !hasmissing(Cinv)); ///
                st_numscalar("`__hddid_covinv_inv_tol'", 1e-7); ///
                if (!hasmissing(Cinv)) { ///
                    I_C = I(rows(C)); ///
                    inv_gap = max((max(abs(C * Cinv - I_C)), ///
                        max(abs(Cinv * C - I_C)))); ///
                    st_numscalar("`__hddid_covinv_inv_gap'", inv_gap); ///
                } ///
                else { ///
                    st_numscalar("`__hddid_covinv_inv_gap'", .); ///
                }
            if _rc != 0 {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  Unable to verify the returned precision-matrix invertibility"
                di as error "  Reason: equation (4.2) and the parametric debias step require a usable retained covariance inverse in x() space"
                exit 198
            }
            if scalar(`__hddid_covinv_inv_ok') != 1 & ///
                scalar(`__hddid_covinv_diagshort') != 1 & ///
                scalar(`__hddid_covinv_scaleop_ok') != 1 {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  The returned `p' x `p' precision matrix must admit a finite inverse reconstruction"
                di as error "  Reason: equation (4.2) and the downstream beta-debias step use this object as a retained covariance inverse operator"
                exit 198
            }
            if scalar(`__hddid_covinv_min_sval') <= ///
                scalar(`__hddid_covinv_sval_tol') & ///
                scalar(`__hddid_covinv_inv_gap') > ///
                scalar(`__hddid_covinv_inv_tol') & ///
                scalar(`__hddid_covinv_diagshort') != 1 & ///
                scalar(`__hddid_covinv_scaleop_ok') != 1 {
                quietly _hddid_pfc_restore, ///
                    nfrestore(`_hddid_clime_restore_scalar') ///
                    rawrestore(`_hddid_clime_restore_raw_scalar') ///
                    nfprior(`__hddid_clime_prior') ///
                    rawprior(`__hddid_clime_raw_prior')
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  The returned `p' x `p' precision matrix must be numerically invertible"
                di as error "  min singular value    = " %12.4e scalar(`__hddid_covinv_min_sval')
                di as error "  invertibility tol     = " %12.4e scalar(`__hddid_covinv_sval_tol')
                di as error "  inverse accuracy gap  = " %12.4e scalar(`__hddid_covinv_inv_gap')
                di as error "  inverse-gap tol       = " %12.4e scalar(`__hddid_covinv_inv_tol')
                di as error "  Reason: equation (4.2) and the downstream beta-debias step use this object as a retained covariance inverse operator, not just a symmetric feasible matrix"
                exit 198
            }
            // Paper equation (4.2) and the R implementation use the retained
            // operator directly once it is finite, square, and numerically
            // invertible. For p>1 this bridge therefore does not add a
            // diagonal-sign gate on top of the operator/invertibility checks
            // above: a custom sidecar may still publish a usable right-multiplier
            // whose diagonal entries are not all positive.
            local _clime_nfolds_cv_realized = scalar(__hddid_clime_effective_nfolds)
            if `_hddid_clime_restore_scalar' {
                capture scalar drop __hddid_clime_effective_nfolds
                scalar __hddid_clime_effective_nfolds = ///
                    scalar(`__hddid_clime_prior')
            }
            else {
                capture scalar drop __hddid_clime_effective_nfolds
            }
            tempname __hddid_covinv_feas_gap __hddid_covinv_feas_cap
            tempname __hddid_covinv_feas_tol __hddid_covinv_diag_gap
            tempname __hddid_covinv_diag_tol
            capture scalar drop `__hddid_covinv_feas_gap'
            capture scalar drop `__hddid_covinv_feas_cap'
            capture scalar drop `__hddid_covinv_feas_tol'
            capture scalar drop `__hddid_covinv_diag_gap'
            capture scalar drop `__hddid_covinv_diag_tol'
            if scalar(`__hddid_covinv_diagshort') == 1 | ///
                (`_clime_nfolds_cv_realized' == 0 & ///
                 (scalar(`__hddid_covinv_rawdiagshort') == 1 | ///
                  scalar(`__hddid_covinv_rawscaleop_ok') == 1)) {
                scalar `__hddid_covinv_feas_gap' = 0
                scalar `__hddid_covinv_feas_cap' = 0
                scalar `__hddid_covinv_feas_tol' = 2.220446049250313e-16
                scalar `__hddid_covinv_diag_gap' = 0
                scalar `__hddid_covinv_diag_tol' = 2.220446049250313e-16
            }
            else {
                // The CLIME lambda contract already absorbs solver-side
                // approximation error. The post-write check only needs
                // enough slack for matrix-multiply/bridge roundoff on the
                // dimensionless Sigma*Omega product itself. Evaluate that
                // bound on equation (4.2)'s raw retained second moment rather
                // than a recentered surrogate, while still rescaling before
                // crossproducts so finite retained covariances do not fail
                // closed merely because X'X or x_scale^2 overflows before the
                // final /n normalization is applied.
                capture mata: X = st_matrix("`__hddid_tildex'"); ///
                    n = rows(X); ///
                    Omega = st_matrix("`__hddid_covinv'"); ///
                    x_scale = max(abs(X)); ///
                    if (x_scale <= 0 | x_scale >= .) { ///
                        SigmaOmega = (I(cols(X)) / sqrt(n)) * Omega; ///
                        offdiag = J(cols(X), cols(X), 0); ///
                        pair_scale = J(cols(X), cols(X), 1); ///
                    } ///
                    else { ///
                        inv_x_scale = 1 / x_scale; ///
                        inv_x_scale_sq = inv_x_scale / x_scale; ///
                        Xs = X :/ x_scale; ///
                        Sigma_scaled = quadcross(Xs, Xs) / n; ///
                        offdiag = Sigma_scaled - diag(diagonal(Sigma_scaled)); ///
                        pair_scale = sqrt(abs(diagonal(Sigma_scaled) * diagonal(Sigma_scaled)')); ///
                        pair_scale = pair_scale + (pair_scale :== 0); ///
                        Omega_scaled = Omega * x_scale; ///
                        if (!hasmissing(Omega_scaled)) { ///
                            Omega_scaled = Omega_scaled * x_scale; ///
                        } ///
                        if (!hasmissing(Omega_scaled)) { ///
                            SigmaOmega = Sigma_scaled * Omega_scaled + ///
                                (I(cols(X)) / sqrt(n)) * Omega; ///
                        } ///
                        else { ///
                            Sigma = quadcross(Xs, Xs) * ((x_scale * x_scale) / n); ///
                            SigmaOmega = (Sigma + I(cols(X)) / sqrt(n)) * Omega; ///
                        } ///
                    }; ///
                    gap = max(abs(SigmaOmega - I(cols(X)))); ///
                    cap = max(abs(offdiag)) * (x_scale * x_scale); ///
                    tol = max(( ///
                        2.220446049250313e-16 * max((1, max(abs(SigmaOmega)))) * cols(X), ///
                        0.15 * max((cap, 1e-10)) ///
                    )); ///
                    diag_gap = max(abs(offdiag) :/ pair_scale); ///
                    diag_tol = 2.220446049250313e-16; ///
                    st_numscalar("`__hddid_covinv_feas_gap'", gap); ///
                    st_numscalar("`__hddid_covinv_feas_cap'", cap); ///
                    st_numscalar("`__hddid_covinv_feas_tol'", tol); ///
                    st_numscalar("`__hddid_covinv_diag_gap'", diag_gap); ///
                    st_numscalar("`__hddid_covinv_diag_tol'", diag_tol)
                if _rc != 0 {
                    di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                    di as error "  Unable to verify the returned retained-sample CLIME feasibility bound"
                    di as error "  Reason: with p>1, the paper/R CLIME path requires a retained-sample covariance inverse that approximately solves Sigma_tildex * Omega = I columnwise"
                    exit 198
                }
            }
            local _clime_zero_diag_shortcut 0
            local _clime_zero_raw_scaleop 0
            if `_clime_nfolds_cv_realized' == 0 & ///
                scalar(`__hddid_covinv_rawdiagshort') == 1 {
                local _clime_zero_diag_shortcut 1
            }
            if `_clime_nfolds_cv_realized' == 0 & ///
                scalar(`__hddid_covinv_rawscaleop_ok') == 1 {
                local _clime_zero_raw_scaleop 1
            }
            if (`_clime_nfolds_cv_realized' < 2 | ///
                `_clime_nfolds_cv_realized' != floor(`_clime_nfolds_cv_realized') | ///
                `_clime_nfolds_cv_realized' > `_clime_nfolds_cv') & ///
                `_clime_zero_diag_shortcut' == 0 & ///
                `_clime_zero_raw_scaleop' == 0 {
                di as error "{bf:hddid}: CLIME sidecar reported an invalid realized CV fold count in fold `_k'"
                if `_clime_nfolds_cv_realized' == 0 {
                    di as error "  The sidecar reported zero realized CV folds on a multivariate retained-sample CLIME solve"
                    di as error "  p>1 CLIME tuning requires a realized fold count in [2, `_clime_nfolds_cv'] unless the returned raw-second-moment operator itself certifies either the exact diagonal shortcut or the exact raw Sigma_tildex * Omega = I operator shortcut"
                    di as error "  max |offdiag(Sigma_tildex)| = " ///
                        %12.4e scalar(`__hddid_covinv_feas_cap')
                    di as error "  pair-scale diagonal gap   = " ///
                        %12.4e scalar(`__hddid_covinv_diag_gap')
                    di as error "  diagonal shortcut tol     = " ///
                        %12.4e scalar(`__hddid_covinv_diag_tol')
                    di as error "  Reason: equation (4.2) only needs the retained-sample covariance inverse; a zero-fold shortcut is valid when the returned raw operator itself already certifies the retained inverse contract, even if the exact operator is non-diagonal"
                }
                else {
                    di as error "  p>1 CLIME tuning requires a realized fold count in [2, `_clime_nfolds_cv']"
                    di as error "  requested effective cap=`_clime_nfolds_cv', reported=`_clime_nfolds_cv_realized'"
                }
                exit 198
            }
            if scalar(`__hddid_covinv_feas_gap') > ///
                scalar(`__hddid_covinv_feas_cap') + ///
                scalar(`__hddid_covinv_feas_tol') {
                capture noisily _hddid_pfc_clime_feas_ok ///
                    `=scalar(`__hddid_covinv_feas_gap')' ///
                    `=scalar(`__hddid_covinv_feas_cap')' ///
                    `=scalar(`__hddid_covinv_feas_tol')' ///
                    `_hddid_clime_raw_feasible'
                if _rc != 0 {
                    di as error "{bf:hddid}: CLIME sidecar wrote an invalid published-feasibility contract in fold `_k'"
                    di as error "  Unable to evaluate whether the symmetric published matrix is admissible after flare-style symmetrization"
                    exit 198
                }
                if r(allowed) == 1 {
                    local _hddid_clime_effective = `_clime_nfolds_cv_realized'
                }
                else {
                di as error "{bf:hddid}: CLIME sidecar wrote an invalid precision matrix contract in fold `_k'"
                di as error "  The returned `p' x `p' precision matrix violates the retained-sample CLIME feasibility bound"
                di as error "  max |Sigma_tildex * Omega - I| = " ///
                    %12.4e scalar(`__hddid_covinv_feas_gap')
                di as error "  CLIME lambda upper bound       = " ///
                    %12.4e scalar(`__hddid_covinv_feas_cap')
                di as error "  tolerance                      = " ///
                    %12.4e scalar(`__hddid_covinv_feas_tol')
                di as error "  Reason: with p>1, hddid's retained-sample CLIME grid uses lambda <= max |offdiag(Sigma_tildex)|, so a valid CLIME output must satisfy that feasibility inequality before beta debiasing can proceed"
                exit 198
            }
            }
            else {
                local _hddid_clime_effective = `_clime_nfolds_cv_realized'
            }
        }

        // Pass missing to Mata when the caller requested no seed so bootstrap
        // and helper failure paths never publish a partial precision matrix.
        matrix `__hddid_covinv_target' = `__hddid_covinv'

    return scalar clime_effective = `_hddid_clime_effective'
    return scalar scipy_validated = `_hddid_scipy_validated'
end
