let status_checker = "fdstatus.exe"

let _ =
  let args = Array.copy Sys.argv in
  let image = Filename.concat Filename.current_dir_name status_checker in
  args.(0) <- status_checker;
  if Sys.argv.(1) = "execv" then
    Unix.execv image args
  else
    let pid =
      Unix.create_process image args Unix.stdin Unix.stdout Unix.stderr in
    ignore (Unix.waitpid [] pid)
