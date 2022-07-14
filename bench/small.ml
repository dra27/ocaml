open Buffer

let add_string b s =
  let len = String.length s in
  let new_position = b.position + len in
  if new_position > b.length then resize b len;
  Bytes.unsafe_blit_string s 0 b.buffer b.position len;
  b.position <- new_position

let add_string_std_nospill b s =
   let len = String.length s in
   let new_position = b.position + len in
   if new_position > b.length then begin
     resize b len;
     Bytes.unsafe_blit_string s 0 b.buffer b.position len
   end else
     Bytes.unsafe_blit_string s 0 b.buffer b.position len;
   b.position <- new_position
