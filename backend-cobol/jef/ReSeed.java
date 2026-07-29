import java.nio.charset.Charset; import java.io.*;
public class ReSeed {
  static final Charset JEF=Charset.forName("x-Fujitsu-JEF-EBCDIC");
  static String hex(String s){ if(s==null)s=""; s=s.trim(); byte[] b=s.getBytes(JEF); StringBuilder h=new StringBuilder(); for(byte x:b) h.append(String.format("%02X",x)); while(h.length()<40) h.append("40"); if(h.length()>40) h.setLength(40); return h.toString(); }
  public static void main(String[] a) throws Exception {
    BufferedReader r=new BufferedReader(new InputStreamReader(System.in,"UTF-8")); String line;
    while((line=r.readLine())!=null){ line=line.trim(); if(line.isEmpty())continue;
      String[] p=line.split("[|]",-1); if(p.length<3)continue;
      System.out.println("UPDATE KOUZA SET MEIGI_KANJI=HEXTORAW('"+hex(p[1])+"'), MEIGI_KANA=HEXTORAW('"+hex(p[2])+"') WHERE KOUZA_NO="+p[0].trim()+";");
    }
    System.out.println("COMMIT;"); System.out.println("EXIT;");
  }
}
