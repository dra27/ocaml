let worker b n () =
  let old_size = ref (Buffer.length b) in
  let s = String.make 500 'x' in
  while true do
    let l = Buffer.length b in
    if !old_size <> l then begin
      Format.eprintf "%d size: %d\n%!" n l;
      old_size := l;
    end;
    let () = Buffer.reset b in
    try
    Buffer.add_string b s
    with e -> Printf.eprintf "%s\n%!" (Printexc.to_string e)
  done

let _ =
  let buffer = Buffer.create 1024 in
  let _ = Domain.spawn (worker buffer 1)   in
  let _ = Domain.spawn (worker buffer 2)   in
  let _ = Domain.spawn (worker buffer 3)   in
  let _ = Domain.spawn (worker buffer 4)  in
  let _ = Domain.spawn (worker buffer 5)   in
  let _ = Domain.spawn (worker buffer 6)   in
  let _ = Domain.spawn (worker buffer 7)   in
  let _ = Domain.spawn (worker buffer 8)   in
  while true do () done
