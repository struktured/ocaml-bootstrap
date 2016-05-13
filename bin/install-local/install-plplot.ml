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
module Git = Shell_support.Git
let target_default = Shell.opam_system_root ()
let target =
  let doc = "Specifies the target installation directory." in
  Arg.(value & opt string target_default & info ["o";"target"] ~doc
         ~docv:"DIR")

let url_default  =
"http://git.code.sf.net/p/plplot/plplot.git"

let url =
  let doc = "Url to fetch plplot sources from" in
  Arg.(value & opt string url_default & info ["u";"url"] ~doc
         ~docv:"URL")

let version_default = "plplot-5.11.1"
let version_tag =
  let doc = "Git version tag to build source from" in
  Arg.(value & opt string version_default & info ["t";"tag"] ~doc
         ~docv:"VERSION_TAG")
let print s = Printf.printf "[install_plplot]: %s\n" s

let fetch_package ~version_tag url = 
  let target = ".install-" ^ version_tag in
  Git.clone ~target ~ssl_no_verify:true ~branch_or_tag:version_tag url 

let make ~target dir =
  let open Shell.Infix in
  Shell.in_dir dir @@ fun dir ->
  Shell.system @@ 
    "cmake" ^ " " ^ 
    "-DBUILD_STATIC_LIBS=ON" ^ " " ^
    "-DBUILD_SHARED_LIBS=ON"  ^ " " ^
    "-DCMAKE_INSTALL_PREFIX=" ^
  target >>= fun res -> ignore(res);
  Shell.system @@ "make install"

let run target url version_tag =
  let urls = Re.split (Re_posix.compile_pat ";" ) url in
  let open Shell.Infix in
  CCList.fold_while (fun res url -> 
  match fetch_package ~version_tag url with 
    `Ok s as ok -> print s; ok, `Stop 
  | `Error (_, e) as err -> print ("Error fetching from " ^ url ^ ": " ^ e);
    err, `Continue) (`Ok "") urls >>= 
  make ~target
  
let cmd =
  let doc = "Compile and install plplot library" in
  Term.(ret (pure run $ target $ url $ version_tag)),
  Term.info "install_plplot" ~version:"1.0" ~doc 

let () = match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
