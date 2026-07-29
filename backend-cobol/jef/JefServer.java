import java.io.*; import java.net.*; import java.nio.charset.Charset;
public class JefServer {
  static final Charset JEF = Charset.forName("x-Fujitsu-JEF-EBCDIC");
  static String hex(byte[] b){StringBuilder s=new StringBuilder();for(byte x:b)s.append(String.format("%02X",x));return s.toString();}
  static byte[] unhex(String s){s=s.trim();int n=s.length()/2;byte[] b=new byte[n];for(int i=0;i<n;i++)b[i]=(byte)Integer.parseInt(s.substring(2*i,2*i+2),16);return b;}
  public static void main(String[] a) throws Exception {
    int port = a.length>0?Integer.parseInt(a[0]):9099;
    ServerSocket ss=new ServerSocket(port,50,InetAddress.getByName("127.0.0.1"));
    System.out.println("JefServer 127.0.0.1:"+port);
    while(true){ Socket c=ss.accept();
      try(BufferedReader r=new BufferedReader(new InputStreamReader(c.getInputStream(),"UTF-8"));
          BufferedWriter w=new BufferedWriter(new OutputStreamWriter(c.getOutputStream(),"UTF-8"))){
        String line=r.readLine(); String out="";
        if(line!=null&&line.length()>=1){ char m=line.charAt(0);
          String arg=line.length()>2?line.substring(2):"";
          if(m=='E') out=hex(new String(unhex(arg),"UTF-8").getBytes(JEF));
          else if(m=='D') out=hex(new String(unhex(arg),JEF).getBytes("UTF-8"));
        }
        w.write(out); w.write("\n"); w.flush();
      }catch(Exception e){} c.close();
    }
  }
}
