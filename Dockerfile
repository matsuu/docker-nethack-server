FROM debian

RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf bison \
    bsdmainutils flex gcc git groff libncursesw5-dev libsqlite3-dev make \
    ncurses-dev sqlite3 tar telnetd-ssl xinetd locales && \
  apt-get clean

RUN locale-gen en_US.UTF-8

RUN git clone git://github.com/paxed/dgamelaunch.git && \
  cd dgamelaunch && \
  sed -i \
    -e "s/-lrt/-lrt -pthread/" \
    configure.ac && \
  sed -i \
    -e "/^maxnicklen/s/=.*/= 20/" \
    -e "/game_\(path\|args\)/s/nethack/nethack.343-nao/" \
    -e "/^commands\[\(register\|login\)\]/s/=\(.*\)/= mkdir \"%ruserdata\/%N\",\n\1/" \
    -e "s:/%n:/%N/%n:" \
    examples/dgamelaunch.conf && \
  ./autogen.sh \
    --enable-sqlite \
    --enable-shmem \
    --with-config-file=/opt/nethack/nethack.alt.org/etc/dgamelaunch.conf && \
  make && \
  ./dgl-create-chroot && \
  cd .. && \
  rm -rf dgamelaunch

RUN git clone http://alt.org/nethack/nh343-nao.git && \
  cd nh343-nao && \
  sed -i \
    -e "/^CFLAGS/s/-O/-O2 -fomit-frame-pointer -fcommon/" \
    sys/unix/Makefile.src && \
  sed -i \
    -e "/rmdir \.\/-p/d" \
    sys/unix/Makefile.top && \
  sed -i \
    -e "/^CFLAGS/s/-O/-O2 -fomit-frame-pointer -fcommon/" \
    sys/unix/Makefile.utl && \
  make all && \
  make install && \
  cd .. && \
  rm -rf nh343-nao

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
