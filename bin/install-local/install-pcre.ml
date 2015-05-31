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

let target_default = Shell.opam_bin_root ()

let target =
  let doc = "Specifies the target installation directory." in
  Arg.(value & opt string target_default & info ["o";"target"] ~doc
         ~docv:"DIR")

let url_default  = 
  "http://sourceforge.net/projects/pcre/files/pcre/8.37/pcre-8.37.tar.gz"

let url =
  let doc = "Url to fetch pcre sources from" in
  Arg.(value & opt string url_default & info ["u";"url"] ~doc
         ~docv:"URL")

let print s = Printf.printf "[install_pcre]: %s\n" s

let fetch_package url = 
  let open Shell.Infix in
  let basename = FilePath.basename url in begin
  match String.lowercase @@ FilePath.get_extension basename with
    | "tgz" -> `Ok (FilePath.replace_extension basename "tar.gz")
    | "gz" | "bzip2" -> `Ok basename
    | s -> `Error (false, "unknown package extension: " ^ s)
  end >>= fun output_file ->
  Wget.run
    ~no_check_certificate:true
    ~output_documents:output_file
    url >>| fun res -> print res;output_file

let decompress filename =
  let open Shell.Infix in
  let chopped =  FilePath.chop_extension filename in
  FileUtil.rm ~recurse:true ~force:FileUtil.Force [chopped; FilePath.chop_extension chopped];
  Decompress.run filename

let extract_tar filename =
    let open Shell.Infix in
    Shell.run @@ "tar xvf " ^ filename >>= fun res -> ignore(res);
    `Ok (FilePath.chop_extension filename)

let make ~target dir =
  let open Shell.Infix in
  Shell.in_dir dir @@ fun _ ->
  Shell.system @@ "./configure --prefix=" ^ target >>=
  fun res -> ignore(res); Shell.system "make" >>=
  fun res -> ignore(res); Shell.system "make install"

let run target url =
  let open Shell.Infix in
  fetch_package url >>= fun s -> print s;
  decompress s >>= 
  extract_tar >>=
  make ~target
  
let cmd =
  let doc = "Compile and install pcre." in
  Term.(ret (pure run $ target $ url)),
  Term.info "install_pcre" ~version:"1.0" ~doc 

let () = match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
