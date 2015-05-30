#!/usr/bin/env ocamlscript
let open Ocamlscript.Std in 
begin
  Ocaml.packs :=
    ["extlib";"re";"unix";"cmdliner";"fileutils";"re.posix";"containers";"shell_support"]
end
--
()

open Cmdliner
open Shell_support

let home = Shell.home
let scripts_dir_name = "bin"

let working_dir =
  FilePath.dirname Sys.argv.(0) |> fun s ->
  match s with "." -> FilePath.parent_dir | _ ->
  match Re.split (Re_posix.compile_pat scripts_dir_name) s with
    h::hs -> h
  | [] -> FilePath.current_dir
            
let _ = Printf.printf "Working directory: %s\n" working_dir

let profiles_default_url = 
  try
    Unix.getenv "OCAML_PROFILES_URL"  
 with Not_found -> "https://github.com/struktured/ocaml-profiles"

let profiles_url =
  let doc = "Specifies a ocam profile repository to fetch profiles from. " ^
            "OCAML_PROFILES_URL environment variable overrides the default value." in
  Arg.(value & (opt string) profiles_default_url & info ["r";"repo"] ~doc ~docv:"URL")

let opam_default = FilePath.concat home ".opam"
let pinned_file_name = "pinned"
let package_file_name = "packages"
let compiler_version_default = "4.02.1"
let no_ssl_verify_opt = "GIT_SSL_NO_VERIFY=true"

let profiles_dir = "profiles"
let profile_dir profile = FilePath.concat profiles_dir profile

let pinned_config_file profile = FilePath.concat (profile_dir profile)
    pinned_file_name

let pins profile =
  let file = pinned_config_file profile in open_in file |>
  Std.input_list

let package_config_file profile = FilePath.concat (profile_dir profile)
    package_file_name

let packages profile =
  let file = package_config_file profile in open_in file |>
  Std.input_list |> List.map (fun s -> Re.split (Re_posix.compile_pat " ") s) |> List.flatten

let pinned_config_file_target opam_repo_target compiler_version
  = FilePath.concat opam_repo_target @@
    FilePath.concat compiler_version pinned_file_name

module Kind = struct
  type t = [`Git | `Path | `Hg | `Darcs]
  let to_string = function `Git -> "git" | `Path -> "path" | `Hg -> "hg"
   | `Darcs -> "darcs"
  let of_string s = match String.lowercase s with
   | "path" -> `Path
   | "git" -> `Git
   | "hg" -> `Hg
   | "darcs" -> `Darcs
   | k -> failwith("unknown kind: " ^ k)
end

type pin_entry = {name:string;kind:Kind.t; target:string}

let pins profile =
  let file = pinned_config_file profile in open_in file |>
  Std.input_list |>
  List.map String.trim |>
  List.filter (fun s -> String.length s > 0) |>
  List.map (fun s -> Re.split (Re_posix.compile_pat " ") s) |>
  List.map (function [name;kind;target] ->
             {name;kind=Kind.of_string kind;target} | 
               l -> failwith("unxpected number of columns for line: " ^
                                 String.concat " " l))
let read_all (dir:string) = 
  let dir = Unix.opendir dir in
  let rec iter l = try 
      let entry = Unix.readdir dir in 
      if String.contains_from entry 0 '.' then iter l else
      entry::(iter l) with End_of_file -> l in
  iter []

(* TODO not implemented *)
let get_profiles () = ["None"]

let profile =
  let doc = "Specifies a profile to apply to the repository. "
            (* ^ "Possible choices are: \n[" ^ 
            (String.concat ", " @@ get_profiles ()) ^ "]." *) in
  Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"PROFILE")

let opam_repo_target =
  let doc = "Specifies the target opam repository, typically ~/.opam" in
  Arg.(value & opt string opam_default & info ["o";"target"] ~doc
         ~docv:"TARGET")

let compiler_version =
  let doc = "Specifies the ocaml compiler version, defaults to " ^
            compiler_version_default in
  Arg.(value & opt string compiler_version_default & info ["comp";"c"] ~doc
         ~docv:"COMPILER_VERSION")

open Shell.Infix

let print s = Printf.printf "[appy_profile]: %s\n" s

let checkout_profile profile url =
  let profile_dir = profile_dir profile in 
  Git.clone ~target:profile_dir ~branch_or_tag:profile url

let add_pins profile =
  let pins = pins profile in
  let remove_pin {name;kind;target} =
      Shell.system @@ Printf.sprintf "opam pin -n -y remove %s" name in
  let add_pin {name;kind;target} =
      Shell.system @@ Printf.sprintf "opam pin -y add -k %s %s %s"
        (Kind.to_string kind) name target in
  let remove_add p = remove_pin p >>= fun s -> print s; add_pin p >>=
    fun s -> print s; `Ok ("added and removed " ^ p.name) in
  CCList.fold_while (fun res pin -> 
      match res with 
       | `Error _ as e -> e, `Stop
       | `Ok _ -> (remove_add pin), `Continue) (`Ok "apply_pins: start") pins

let opam_switch profile compiler_version =
  let switch_cmd = no_ssl_verify_opt ^ " opam switch " ^ compiler_version in
  Shell.system switch_cmd >>= fun _ ->
  let eval_cmd = "eval `opam config env`" in
  Shell.system eval_cmd

let install_packages profile =
  let packages = packages profile in
  let install_cmd = no_ssl_verify_opt ^ " opam reinstall -y " ^ (String.concat " " packages) in
  let ret = Sys.command install_cmd in 
  if ret != 0 then `Error (false, Printf.sprintf "%s: nonzero exit status: %d"
                             install_cmd ret) else
  `Ok "Done installing packages"

let run profile opam_repo_target compiler_version profiles_url =
  print @@ Printf.sprintf "\"%s\" to opam repository \"%s\" with
  compiler version %s...\n" profile opam_repo_target compiler_version;
  opam_switch profile compiler_version >>= fun s -> print s;
  ignore(checkout_profile profile profiles_url);
  add_pins profile >>= fun s -> print s;
  install_packages profile

let cmd =
  let doc = "Apply an ocaml profile to a target opam repository" in
  Term.(ret (pure run $ profile $ opam_repo_target $ compiler_version $ profiles_url)),
  Term.info "apply_profile" ~version:"1.0" ~doc

let () = match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
