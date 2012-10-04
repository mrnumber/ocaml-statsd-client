(** Send statistics to the stats daemon over UDP

    Both a synchronous (Sync) and an asynchronous (Lwt) version are provided.
*)

val ipaddr : string option ref
val port : int option ref

val log_debug : (string -> unit) ref
  (** Default: do nothing. *)

val log_error : (string -> unit) ref
  (** Default: log to stderr. *)

module Sync :
  sig
    val gauge : ?sample_rate:float -> string -> int -> unit

    val timing : ?sample_rate:float -> string -> int -> unit
      (** Log timing info. time is an int of milliseconds. *)

    val timingf : ?sample_rate:float -> string -> float -> unit
      (** Log timing info. time is a float of seconds which will
          be converted to milliseconds. *)

    val update_stats : ?sample_rate:float -> int -> string list -> unit
      (** Update a list of counter stats by some delta *)

    val increment : ?sample_rate:float -> string list -> unit
      (** Increment a list of counter stats by one *)

    val decrement : ?sample_rate:float -> string list -> unit
      (** Decrement a list of counter stats by one *)
  end

module Lwt :
  sig
    val gauge : ?sample_rate:float -> string -> int -> unit Lwt.t
    val timing : ?sample_rate:float -> string -> int -> unit Lwt.t
    val timingf : ?sample_rate:float -> string -> float -> unit Lwt.t
    val update_stats : ?sample_rate:float -> int -> string list -> unit Lwt.t
    val increment : ?sample_rate:float -> string list -> unit Lwt.t
    val decrement : ?sample_rate:float -> string list -> unit Lwt.t
  end
