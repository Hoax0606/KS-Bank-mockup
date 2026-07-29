import java.nio.charset.Charset; import java.io.*;
public class JefHex {
  static final Charset JEF=Charset.forName("x-Fujitsu-JEF-EBCDIC");
  public static void main(String[] a) throws Exception {
    BufferedReader r=new BufferedReader(new InputStreamReader(System.in,"UTF-8")); String s;
    while((s=r.readLine())!=null){ s=s.trim(); if(s.isEmpty())continue;
      byte[] b=s.getBytes(JEF); StringBuilder h=new StringBuilder();
      for(byte x:b) h.append(String.format("%02X",x));
      while(h.length()<40) h.append("40"); if(h.length()>40) h.setLength(40);
      System.out.println(s+"\t"+h);
    }
  }
}
