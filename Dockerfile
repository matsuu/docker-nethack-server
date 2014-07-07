FROM ubuntu

RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf bison \
    bsdmainutils flex gcc git groff libncursesw5-dev libsqlite3-dev make \
    ncurses-dev sqlite3 tar telnetd-ssl wget xinetd && \
  apt-get clean

RUN locale-gen ja_JP.UTF-8

RUN git clone git://github.com/paxed/dgamelaunch.git && \
  cd dgamelaunch && \
  sed -i \
    -e "s/-lrt/-lrt -pthread/" \
    configure.ac && \
  sed -i \
    -e "/^maxnicklen/s/=.*/= 16/" \
    examples/dgamelaunch.conf && \
  ./autogen.sh \
    --enable-sqlite \
    --enable-shmem \
    --with-config-file=/opt/nethack/nethack.alt.org/etc/dgamelaunch.conf && \
  make && \
  ./dgl-create-chroot && \
  cd .. && \
  rm -rf dgamelaunch

RUN \
  wget \
    http://sourceforge.net/projects/nethack/files/nethack/3.4.3/nethack-343-src.tgz && \
  tar zxf nethack-343-src.tgz && \
  cd nethack-3.4.3 && \
  sh sys/unix/setup.sh x && \
  sed -i \
    -e "/^CFLAGS/s/-O/-O2 -fomit-frame-pointer/" \
    -e "/^WINTTYLIB/s/=.*/= -lncurses/" \
    sys/unix/Makefile.src && \
  sed -i \
    -e "/^CFLAGS/s/-O/-O2 -fomit-frame-pointer/" \
    -e "/^YACC /s/=.*/= bison -y/" \
    sys/unix/Makefile.utl && \
  sed -i \
    -e "/rmdir \.\/-p/d" \
    -e "/^PREFIX/s:=.*:= /opt/nethack/nethack.alt.org:" \
    -e "/^GAMEDIR/s:=.*:= \$(PREFIX)/nh343:" \
    -e "/^VARDIR/s:=.*:= \$(GAMEDIR)/var:" \
    -e "/^GAMEGRP/s:=.*:= games:" \
    sys/unix/Makefile.top && \
  sed -i \
    -e "/define HACKDIR/s:\".*\":\"/nh343\":" \
    -e "/define COMPRESS /s:\".*\":\"/bin/gzip\":" \
    include/config.h && \
  sed -i \
    -e "s:/\* \(#define\s*\(SYSV\|LINUX\|TERMINFO\|TIMED_DELAY\)\)\s*\*/:\1:" \
    -e "s:/\* \(#define VAR_PLAYGROUND\).*:\1 \"/nh343/var\":" \
    include/unixconf.h && \
  sed -i \
    -e "/^enter_explore_mode()/a {return 0;}\nSTATIC_PTR int _enter_explore_mode()" \
    src/cmd.c && \
  sed -i \
    -e "/^#define ENTRYMAX/s/100/10000/" \
    -e "/^#define NAMSZ/s/10/16/" \
    -e "/^#define PERS_IS_UID/d" \
    src/topten.c && \
  make all && \
  make install && \
  cd .. && \
  rm -rf \
    nethack-3.4.3 \
    nethack-343-src.tgz

RUN tar cf - \
  /lib/x86_64-linux-gnu/libncurses* \
  | tar xf - -C /opt/nethack/nethack.alt.org/

RUN ( \
  echo "service telnet" && \
  echo "{" && \
  echo "  socket_type = stream" && \
  echo "  protocol    = tcp" && \
  echo "  user        = root" && \
  echo "  wait        = no" && \
  echo "  server      = /usr/sbin/in.telnetd" && \
  echo "  server_args = -L /opt/nethack/nethack.alt.org/dgamelaunch" && \
  echo "  rlimit_cpu  = 120" && \
  echo "}" \
) > /etc/xinetd.d/dgl

VOLUME ["/opt/nethack/nethack.alt.org/nh343/var", "/opt/nethack/nethack.alt.org/dgldir"]

EXPOSE 23

CMD ["xinetd", "-dontfork"]
