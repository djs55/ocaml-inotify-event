(*
 * Copyright (c) 2016 David Sheets <david.sheets@docker.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

type format =
  | String
  | Sexp

let string_of_event = function
  | String -> Inotify.string_of_event
  | Sexp -> fun event ->
    Sexplib.Sexp.to_string_hum (Inotify_event.sexp_of_t event)

let stream format events dir n =
  let dir = match dir with None -> Sys.getcwd () | Some x -> x in
  (* We can't sit in the directory being monitored if we want
     termination events. *)
  Sys.chdir "/";
  let inotify = Inotify.create () in
  let _watch = Inotify.add_watch inotify dir events in
  let continue = ref true in
  let remaining = ref n in
  while !continue && !remaining <> (Some 0) do
    (* Block until there is something to read. Otherwise, our ioctl
       returns 0 and then makes a 0 read which errors with EINVAL. *)
    ignore (Unix.select [inotify] [] [] ~-.1.);

    let events = Inotify.read inotify in
    List.iter
      (fun ((_, kinds, _, _) as event) ->
         print_endline (string_of_event format event);
         if List.mem Inotify.Ignored kinds
         then continue := false;
         remaining := match !remaining with Some n -> Some (n - 1) | None -> None
      )
      events
  done;
  `Ok ()

open Cmdliner

let stream_cmd =
  let n =
    let doc = "Receive only n events" in
    Arg.(value & opt (some int) None & info [ "n" ] ~doc) in
  let dir =
    let doc = "Watch a particular directory" in
    Arg.(value & opt (some string) None & info [ "dir"] ~doc) in
  let format = Arg.(value (opt (enum [
      "string", String;
      "sexp", Sexp;
    ]) String (info ~docv:"FORMAT" ["format"])))
  in
  (* TODO: separate the different types of events (e.g. oneshot) *)
  let events = Arg.(value (opt (list Inotify.(enum [
      "access",        S_Access;
      "attrib",        S_Attrib;
      "close_write",   S_Close_write;
      "close_nowrite", S_Close_nowrite;
      "create",        S_Create;
      "delete",        S_Delete;
      "delete_self",   S_Delete_self;
      "modify",        S_Modify;
      "move_self",     S_Move_self;
      "moved_from",    S_Moved_from;
      "moved_to",      S_Moved_to;
      "open",          S_Open;
      "dont_follow",   S_Dont_follow;
      "mask_add",      S_Mask_add;
      "oneshot",       S_Oneshot;
      "onlydir",       S_Onlydir;
      "move",          S_Move;
      "close",         S_Close;
      "all",           S_All;
    ])) [Inotify.S_All] (info ~docv:"EVENTS" ["events"])))
  in
  Term.(ret (pure stream $ format $ events $ dir $ n)),
  Term.info "inotify-events" ~doc:"output an inotify event stream"

;;
match Term.eval stream_cmd with
| `Error _ -> exit 1
| _ -> exit 0
