(**************************************************************************)
(*                                                                        *)
(*                        OCamlPro Typerex                                *)
(*                                                                        *)
(*   Copyright OCamlPro 2011-2016. All rights reserved.                   *)
(*   This file is distributed under the terms of the GPL v3.0             *)
(*   (GNU General Public Licence version 3.0).                            *)
(*                                                                        *)
(*     Contact: <typerex@ocamlpro.com> (http://www.ocamlpro.com/)         *)
(*                                                                        *)
(*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       *)
(*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES       *)
(*  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND              *)
(*  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS   *)
(*  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    *)
(*  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN     *)
(*  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE      *)
(*  SOFTWARE.                                                             *)
(**************************************************************************)

module C2S : sig

  module MSG_INIT : sig
    type t = {
      protocol_version : int;
      synchronous_mode : int;
      exe_name : string;
      args : string list;
      pid : int;
      ppid : int;
      curdir : string;
    }
    val to_string : t -> string
  end
  module MSG_EXIT : sig
    type t = { retcode : int }
    val to_string : t -> string
  end
  module MSG_OPEN : sig
    type t = {
      filename : string;
      flags : int;
      perm : int;
      ret : int;
    }
    val to_string : t -> string
  end
  module MSG_CLOSE : sig
    type t = { fd : int; ret : int; }
    val to_string : t -> string
  end
  module MSG_STAT : sig
    type t =  { filename : string; ret : int; }
    val to_string : t -> string
  end
  module MSG_UNLINK : sig
    type t =  { filename : string; ret : int; }
    val to_string : t -> string
  end
  module MSG_RENAME : sig
    type t = {
      old_filename : string;
      new_filename : string;
      ret : int;
    }
    val to_string : t -> string
  end
  module MSG_CHDIR : sig
    type t = { dirname : string; ret : int; }
    val to_string : t -> string
  end
  module MSG_GETENV : sig
    type t =  { var : string; ret : string option; }
    val to_string : t -> string
  end
  module MSG_SYSTEM : sig
    type t = { command : string; ret : int; }
    val to_string : t -> string
  end
  module MSG_READ_DIRECTORY : sig
    type t = { dirname : string; ret : int; }
    val to_string : t -> string
  end



  type msg =
  | MSG_INIT of MSG_INIT.t
  | MSG_EXIT of MSG_EXIT.t
  | MSG_OPEN of MSG_OPEN.t
  | MSG_CLOSE of MSG_CLOSE.t
  | MSG_STAT of MSG_STAT.t
  | MSG_UNLINK of MSG_UNLINK.t
  | MSG_RENAME of MSG_RENAME.t
  | MSG_CHDIR of MSG_CHDIR.t
  | MSG_GETENV of MSG_GETENV.t
  | MSG_SYSTEM of MSG_SYSTEM.t
  | MSG_READ_DIRECTORY of MSG_READ_DIRECTORY.t

  val msg_to_string : msg -> string
  val parse_msg : string -> msg

end

module S2C : sig

  type msg =
  | MSG_ACK

  val marshal : msg -> string

end
