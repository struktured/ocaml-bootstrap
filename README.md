# ocaml-bootstrap
## About
This project aims to streamline installation of OCaml and opam for the logged in user with minimal superuser
access. It's based on the opam bootstrapping build script but adds a few extra phases like checking for 
and installing ```aspcud```, editing your local shell profile to a custom OPAM location, and a path to install 
more (native) packages via [ocamlscript](https://github.com/struktured/ocamlscript) 
and [ocaml-profiles](https://github.com/struktured/ocaml-profiles). 

## Layout

The top level ```bin``` folder contains the main script ```bin/opam-bootstrap.sh```, while the ```bin/install-system``` 
folder has scripts to install system level packages natively, and
```bin/install-local``` has various scripts to install system packages without super user access
(most of which requires [ocamlscript](https://github.com/struktured/ocamlscript) to execute, 
```aspcud``` being the notable exception)

## Usage

First locally clone the stable version of this repository:

```
git clone https://github.com/struktured/ocaml-bootstrap -b stable
```

The bootstrapper does not yet automatically install all native dependencies
required to compile opam. To get around this, first run a script to install
them for your package manager and OS type:


Command                                   | OS Type
------------------------------------------|----------
```bin/install-system/install-ubuntu-deps.sh```  | Ubuntu                              
```bin/install-system/install-redhat-deps.sh```  | Redhat      
```bin/install-system/install-brew-deps.sh```    | OSX/Brew                           
```bin/install-system/install-macport-deps.sh``` | OSX/Macports


If you decide to install these manually, the most important packages are ```pkg-config```, ```curl```, and ```m4```.

To start the bootstrap simply run:

```
cd ocaml-bootstrap
bin/opam-init.sh 
```

which installs the opam binary into $HOME/local/bin by default. Type "--help" to see more options. This command
will take a long time as it compiles both ocaml and opam. After this you're done, but you need to relogin or
reload your profile for the changes to effect.

If you want to install some more ocaml packages or you're interested in using
[ocaml-profiles](https://github.com/struktured/ocaml-profiles), then check out the post install instructions below.

## Post Installation

### Ocaml Profiles and Ocamlscript

You can install ocaml profiles with another bootstrap command:

```
bin/ocaml-profiles-bootstrap.sh 
```

Now run

```
ocaml-profiles ocamlscript 
```

to be able to execute any of the extra install scripts in the bin folder (eg. ```bin/install-local/install-pcre.ml``` 
will install pcre locally with a directory prefix of $HOME/local). Review the contents of ```bin/install-local```
for more examples.

