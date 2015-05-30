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

let target_default = Shell.opam_bin_root

let target =
  let doc = "Specifies the target installation directory." in
  Arg.(value & opt string target_default & info ["o";"target"] ~doc
         ~docv:"DIR")

let defaut_url =
  match Shell.os_type with 
  | `Darwin -> 
    "http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-macos-10.9.tar.gz"
  | `MingW64 -> "http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-win64.zip"
  | `Linux (* Default to linux *)
  | _ -> "http://sourceforge.net/projects/potassco/files/aspcud/1.9.1/aspcud-1.9.1-x86_64-linux.tar.gz"

let url =
  let doc = "Url to fetch aspcud binaries from." in
  Arg.(value & opt string defaut_url & info ["u";"url"] ~doc
         ~docv:"URL")

let print s = Printf.printf "[install_aspcud.ml]: %s\n" s

let fetch_package url = 
  let open Shell.Infix in
  let basename = FilePath.basename url in begin
  match String.lowercase @@ FilePath.get_extension basename with
    | "tgz" -> `Ok (FilePath.replace_extension basename "tar.gz")
    | "zip" | "gz" | "bzip2" -> `Ok basename
    | s -> `Error (false, "unknown package extension: " ^ s)
  end >>= fun output_file ->
  Wget.run
    ~no_check_certificate:true
    ~output_documents:output_file
    url >>| fun res -> print res;output_file

let decompress filename =
  let open Shell.Infix in
  let chopped = FilePath.chop_extension filename in
  FileUtil.rm ~recurse:true ~force:FileUtil.Force [chopped; FilePath.chop_extension chopped];
  Decompress.run filename

let extract_tar_maybe filename =
  let open Shell.Infix in
  match FilePath.get_extension filename with 
  | "tar" -> Shell.run @@ "tar xvf " ^ filename >>= fun res -> ignore(res);
    `Ok (FilePath.chop_extension filename)
  | _ -> `Ok filename


let read_all (dir:string) = 
  let dir = Unix.opendir dir in
  let rec iter l = try 
      let entry = Unix.readdir dir in 
      if String.contains_from entry 0 '.' then iter l else
      entry::(iter l) with End_of_file -> l in
  iter []

let install ~target unpacked_dir =
  let files = List.map (FilePath.concat unpacked_dir)
     (read_all unpacked_dir) in
  let bin = FilePath.concat target "bin" in
  Shell.cp ~recurse:true files bin; `Ok ("installed to " ^ bin)

let run target url =
  let open Shell.Infix in
  print @@ "about to fetch: " ^ url;
  fetch_package url >>= fun s -> print @@ "about to decompress: " ^ s;
  decompress s >>= fun s -> print @@ "about to extract: " ^ s;
  extract_tar_maybe s >>= fun s ->
  print @@ "about to install " ^ s ^ " to " ^ target;
  install ~target s
  
let cmd =
  let doc = "Compile and install aspcud." in
  Term.(ret (pure run $ target $ url)),
  Term.info "install_aspcud.ml" ~version:"1.0" ~doc 

let () = print "start"; match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
