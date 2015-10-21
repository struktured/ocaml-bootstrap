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

let target_default = Shell.opam_system_root ()
let target =
  let doc = "Specifies the target installation directory." in
  Arg.(value & opt string target_default & info ["o";"target"] ~doc
         ~docv:"DIR")

let url_default  =
  "http://www.netlib.org/lapack/lapack-3.5.0.tgz;http://netlib.sandia.gov/lapack/lapack-3.5.0.tgz"

let url =
  let doc = "Url to fetch lapack sources from" in
  Arg.(value & opt string url_default & info ["u";"url"] ~doc
         ~docv:"URL")

let default_profile = "gfortran"

let profile =
  let doc = "Specifies a build profile." in
  Arg.(value & opt string default_profile & info ["p";"profile"] ~doc ~docv:"PROFILE")

let print s = Printf.printf "[install_lapack]: %s\n" s

let fetch_package url = 
  let open Shell.Infix in
  let basename = FilePath.basename url in begin
  match String.lowercase @@ FilePath.get_extension basename with
    | "tgz" -> `Ok (FilePath.replace_extension basename "tar.gz")
    | "gz" | "bz2" -> `Ok basename
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
  Decompress.run filename >>| fun res -> ignore(res); chopped

let extract_tar filename =
    let open Shell.Infix in
    Shell.run @@ "tar xvf " ^ filename >>= fun res -> ignore(res);
    `Ok (FilePath.chop_extension filename)

let make ~profile ~target dir =
  let open Shell.Infix in
  Shell.in_dir dir @@ fun dir ->
  Shell.cp [FilePath.concat "INSTALL" ("make.inc." ^ profile)]
    (FilePath.concat FilePath.current_dir "make.inc");
  Shell.system @@ 
    "cmake" ^ " " ^ 
    "-DBUILD_STATIC_LIBS=ON" ^ " " ^
    "-DBUILD_SHARED_LIBS=ON"  ^ " " ^
    "-DCMAKE_INSTALL_PREFIX=" ^
  target >>= fun res -> ignore(res);
  Shell.system @@ "make install"

let run target url profile =
  let urls = Re.split (Re_posix.compile_pat ";" ) url in
  let open Shell.Infix in
  CCList.fold_while (fun res url -> 
  match fetch_package url with 
    `Ok s as ok -> print s; ok, `Stop 
  | `Error (_, e) as err -> print ("Error fetching from " ^ url ^ ": " ^ e);
    err, `Continue) (`Ok "") urls >>= fun s ->
  decompress s >>= 
  extract_tar >>=
  make ~profile ~target
  
let cmd =
  let doc = "Compile and install lapack and lablas libraries" in
  Term.(ret (pure run $ target $ url $ profile)),
  Term.info "install_lapack" ~version:"1.0" ~doc 

let () = match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
