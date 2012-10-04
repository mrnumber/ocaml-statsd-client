let ipaddr = ref None
let port = ref None

module Make(U : sig
  val ipaddr         : unit -> string option
    (** Get the host ip address.  Allows for dynamic setting *)
  val port           : unit -> int option
    (** Get the port.  Allows for dynamic setting *)

  (** Define these for Lwt or non-Lwt use *)
  type 'a _r
  val (>>=)          : 'a _r -> ('a -> 'b _r) -> 'b _r
  val catch          : (unit -> 'a _r) -> (exn -> 'a _r) -> 'a _r
  val return         : 'a -> 'a _r
  val list_iter      : ('a -> unit _r) -> 'a list -> unit _r

  (** include Lwt_unix or Unix depending on your use *)
  type file_descr
  val socket : Unix.socket_domain -> Unix.socket_type -> int -> file_descr
  val gethostbyname : string -> Unix.host_entry _r
  val getprotobyname : string -> Unix.protocol_entry _r
  val sendto :
    file_descr ->
    string -> int -> int ->
    Unix.msg_flag list -> Unix.sockaddr -> int _r
  val close : file_descr -> unit _r
end) = struct

  let (>>=) = U.(>>=)

  (** The socket reference used to send udp *)
  let socket_ref = ref None

  (** Send the the stats over UDP *)
  let send_with_ipaddr_and_port ipaddr port sample_rate data =
    if sample_rate >= 1.0 || sample_rate >= Random.float 1.0 then
      U.catch (fun () ->
        U.getprotobyname "udp" >>= fun protocol_entry ->
        (* Get or make the socket *)
        let socket =
          match !socket_ref with
            | Some s -> s
            | None   ->
              Log.logf `Debug "Creating statsd socket";
              let s =
                U.socket Unix.PF_INET Unix.SOCK_DGRAM
                  protocol_entry.Unix.p_proto
              in
              socket_ref := Some s;
              s
        in
        let portaddr = Unix.ADDR_INET (Unix.inet_addr_of_string ipaddr, port) in
        (* Map sample_rate to the string statsd expects *)
        let sample_rate =
          if sample_rate >= 1.0 then
            ""  (* not sampling *)
          else
            Printf.sprintf "|@%f" sample_rate
        in
        U.list_iter
          (fun (stat, value) ->
            let msg = Printf.sprintf "%s:%s%s" stat value sample_rate in
            U.sendto socket msg 0 (String.length msg) [] portaddr
            >>= (fun retval ->
              if retval < 0 then
                begin
                  (* Ran into an error, clear the reference
                     and close the socket *)
                  socket_ref := None;
                  U.catch
                    (fun () ->
                      Log.logf `Debug "Closing statsd socket: %d" retval;
                      U.close socket >>= U.return)
                    (fun _e -> U.return ());
                end
              else U.return ()
            )
          )
          data
      ) (fun _e -> U.return ()
      )
    else U.return ()

  let send ?(sample_rate = 1.0) data =
    match U.ipaddr (), U.port () with
      | None, _ | _, None ->
        Log.logf `Error
          "Statsd_client.send: \
           uninitialized Statsd_client.host or Statsd_client.port";
        U.return ()
      | Some ipaddr, Some port ->
        send_with_ipaddr_and_port ipaddr port sample_rate data

  let gauge ?sample_rate stat v =
    send ?sample_rate [stat, Printf.sprintf "%d|g" v]

  (** Log timing info. time is an int of milliseconds. *)
  let timing ?sample_rate stat time =
    send ?sample_rate [stat, Printf.sprintf "%d|ms" time]

  (** Log timing info. time is a float of seconds which will
      be converted to milliseconds. *)
  let timingf ?sample_rate stat time =
    timing ?sample_rate stat (int_of_float (time *. 1000.))

  (** Update a list of counter stats by some delta *)
  let update_stats ?sample_rate delta stats =
    let delta = Printf.sprintf "%d|c" delta in
    send ?sample_rate (List.map (fun stat -> stat, delta) stats)

  (** Increment a list of counter stats by one *)
  let increment ?sample_rate stats =
    update_stats ?sample_rate 1 stats

  (** Decrement a list of counter stats by one *)
  let decrement ?sample_rate stats =
    update_stats ?sample_rate (-1) stats

end

module Sync = Make (
  struct
    let ipaddr () = !ipaddr
    let port () = !port

    type 'a _r = 'a
    let ( >>= ) t f = f t
    let catch f error = try f () with e -> error e
    let return x = x
    let list_iter f lst = List.iter f lst

    include Unix
  end
)

module Lwt = Make (
  struct
    let ipaddr () = !ipaddr
    let port () = !port

    type 'a _r = 'a Lwt.t
    let ( >>= ) = Lwt.bind
    let catch = Lwt.catch
    let return = Lwt.return
    let list_iter = Lwt_list.iter_p

    include Lwt_unix
  end
)
