/* JEFCONV - GnuCOBOL callable bridge to the resident JEF conversion service.
 * COBOL: CALL "JEFCONV" USING MODE(X1) IN(Xn) INLEN(9(4)disp) OUT(Xn) OUTLEN(9(4)disp)
 *   MODE='D' : JEF RAW bytes  -> UTF-8 bytes           (OUT = decoded bytes)
 *   MODE='E' : UTF-8 bytes    -> JEF RAW as HEX ascii  (OUT = hex text, for HEXTORAW)
 *   MODE='H' : IN = JEF hex text (RAWTOHEX result) -> UTF-8 bytes  (decode w/o re-hex)
 * Service 127.0.0.1:$JEF_PORT (default 9099), line protocol "<MODE> <hex>\n" -> "<hex>\n".
 * RETURN-CODE 0=ok, 1=fail(service down) -> caller may fall back. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
static const char* HX="0123456789ABCDEF";
static int rd4(const char*p){return (p[0]-'0')*1000+(p[1]-'0')*100+(p[2]-'0')*10+(p[3]-'0');}
static void wr4(char*p,int v){if(v<0)v=0;if(v>9999)v=9999;p[0]='0'+(v/1000)%10;p[1]='0'+(v/100)%10;p[2]='0'+(v/10)%10;p[3]='0'+v%10;}
static int hv(int c){ if(c>='0'&&c<='9')return c-'0'; c&=0xDF; return c-'A'+10; }
int JEFCONV(char* mode, char* inbuf, char* inlen, char* outbuf, char* outlen){
    int n=rd4(inlen); if(n<0)n=0; if(n>8000)n=8000;
    int port=9099; char*pe=getenv("JEF_PORT"); if(pe&&*pe) port=atoi(pe);
    char req[20000]; int ri=0;
    if(mode[0]=='H'){                         /* IN already hex -> decode as 'D' */
        req[ri++]='D'; req[ri++]=' ';
        for(int i=0;i<n && ri<19980;i++) req[ri++]=inbuf[i];
    } else {
        req[ri++]=mode[0]; req[ri++]=' ';
        for(int i=0;i<n && ri<19980;i++){ unsigned char c=(unsigned char)inbuf[i]; req[ri++]=HX[c>>4]; req[ri++]=HX[c&15]; }
    }
    req[ri++]='\n';
    int fd=socket(AF_INET,SOCK_STREAM,0);
    if(fd<0){ wr4(outlen,0); return 1; }
    struct sockaddr_in a; memset(&a,0,sizeof(a));
    a.sin_family=AF_INET; a.sin_port=htons(port); a.sin_addr.s_addr=inet_addr("127.0.0.1");
    if(connect(fd,(struct sockaddr*)&a,sizeof(a))<0){ close(fd); wr4(outlen,0); return 1; }
    if(write(fd,req,ri)!=ri){ close(fd); wr4(outlen,0); return 1; }
    char resp[40000]; int tot=0,r;
    while(tot < (int)sizeof(resp)-1 && (r=read(fd,resp+tot,sizeof(resp)-1-tot))>0){ tot+=r; if(resp[tot-1]=='\n') break; }
    close(fd);
    while(tot>0 && (resp[tot-1]=='\n'||resp[tot-1]=='\r'||resp[tot-1]==' ')) tot--;
    if(mode[0]=='E'){                       /* keep hex ascii for HEXTORAW */
        if(tot>8000) tot=8000;              /* raised cap for long text fields */
        int i; for(i=0;i<tot;i++) outbuf[i]=resp[i];
        wr4(outlen,tot);
    } else {                                /* 'D'/'H': decode hex -> bytes */
        int on=0,i; for(i=0;i+1<tot;i+=2){ outbuf[on++]=(char)((hv(resp[i])<<4)|hv(resp[i+1])); }
        wr4(outlen,on);
    }
    return 0;
}
