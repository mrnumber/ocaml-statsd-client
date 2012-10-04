.PHONY: default all opt install uninstall

default: all opt

all:
	ocamlfind ocamlc -c statsd_client.mli -package lwt.unix
	ocamlfind ocamlc -a -g statsd_client.ml \
          -o statsd_client.cma -package lwt.unix
opt:
	ocamlfind ocamlc -c statsd_client.mli -package lwt.unix
	ocamlfind ocamlopt -a -g statsd_client.ml \
          -o statsd_client.cmxa -package lwt.unix
install:
	ocamlfind install statsd-client META \
          `find statsd_client.mli statsd_client.cmi \
                statsd_client.cmo statsd_client.cma \
                statsd_client.cmx statsd_client.o \
                statsd_client.cmxa statsd_client.a`
uninstall:
	ocamlfind remove statsd-client

.PHONY: clean
clean:
	rm -f *.cm[ioxa] *.cmxa *.[oa] *~
