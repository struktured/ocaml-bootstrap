#!/usr/bin/env ocamlscript
let open Ocamlscript.Std in
begin
  Ocaml.packs := ["extlib";"re";"unix";"fileutils";"containers"]
end
--
()

let opam_bin_root = try Sys.argv.(1) with _ ->
  FilePath.concat (Unix.getenv "HOME") "local"

let to_append =
  [ "# opam install path updates";
    "export OPAM_BIN_ROOT=" ^ opam_bin_root;
    "export PATH=$PATH:$OPAM_BIN_ROOT/bin:$OPAM_BIN_ROOT/sbin";
    "eval `opam config env`";
    "export OPAMEXTERNALSOLVER=`which aspcud`";
    "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib:$OPAM_BIN_ROOT/lib";
    "export LIBRARY_PATH=$LD_LIBRARY_PATH"]

let not_found l (s:string) = not @@
  List.exists (fun appendee -> s = appendee) l

let config_files = [".bash_profile";".profile";".bashrc"]

let bash_config =
  let paths = List.map (FilePath.concat (Unix.getenv "HOME")) config_files in
  List.map (fun path -> match FileUtil.test FileUtil.Is_file path with
    | true -> Some path
    | false -> None) paths 
  |> CCOpt.choice |> CCOpt.get_lazy (fun () ->
      let path = List.hd paths in
      FileUtil.touch ~create:true path;path)

let _ =
  open_in bash_config |>
  Std.input_list |> fun l -> l @ List.filter (not_found l) to_append
  |> fun l -> List.fold_right (fun e acc -> e ^ "\n" ^ acc) l "" |>
  fun text -> Std.output_file ~filename:bash_config ~text

