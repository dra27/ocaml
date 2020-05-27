using System;
using System.Collections.Generic;
class Concat {
  static void Main() {
    var tests = new List<string>{      @"C:\foo:bar",
      @"C:/foo:bar",
      @"C:foo:bar",
      @"C:",
      @"C:\",
      @"C:/",
      @"\\",
      @"\\srv",
      @"\\srv\shr",
      @"\\.\C:\",
      @"\\?\C:\",
      @"\\.\C:\f",
      @"\\?\C:\f",
      @"\\.\C:\d\f",
      @"\\?\C:\d\f",
      @"\??\C:\",
      @"/??/C:\",
      @"\??\C:\f",
      @"\??\C:\d\f",
    };
    foreach (var test in tests) {
      string GetPathRoot, GetDirectoryName, GetFileName, Combine;
      GetPathRoot = System.IO.Path.GetPathRoot(test);
      GetDirectoryName = System.IO.Path.GetDirectoryName(test);
      GetFileName = System.IO.Path.GetFileName(test);
      try {
        Combine = System.IO.Path.Combine(GetDirectoryName, GetFileName);
      } catch (Exception e) {
        Combine = "<exception>";
      }
      Console.WriteLine("Test   : {0}\nCombine: {1}\nGetPathRoot: {2}\nGetDirectoryName: {3}\nGetFileName: {4}\n",
                        test,
                        Combine,
                        GetPathRoot,
                        GetDirectoryName,
                        GetFileName);
    }
  }
}