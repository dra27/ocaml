using System.Runtime.InteropServices;

public class M {
  [DllImport("main.so")]
  public static extern void start_caml_engine();

  public static void Main() {
    System.Console.WriteLine("Now starting the OCaml engine.");
    start_caml_engine();
  }
}
