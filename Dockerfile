From debian:buster-slim

RUN apt update && apt install -y \
  --no-install-recommends \
  ansible \
  bc \
  bison \
  bridge-utils \
  build-essential \
  ccache \
  flex \
  gcc-aarch64-linux-gnu \
  gdb \
  gdb-multiarch \
  iputils-ping \
  libelf-dev \
  libssl-dev \
  net-tools \
  nfs-kernel-server \
  openssh-client \
  qemu-system-aarch64 \
  qemu-system-x86 \
  qemu-utils \
  screen \
  sshpass \
  sudo \
  tmux \
  vim

# Add user and make passwordless sudo
RUN useradd -ms /bin/bash dev && \
  usermod -aG sudo dev
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> \
  /etc/sudoers

# Set up workdir and copy files
RUN mkdir -p /app/configs /app/disks /app/linux /app/logs /app/share
WORKDIR /app
COPY compile.sh /app/compile.sh
COPY configs/* /app/configs/
RUN chown -R dev /app
USER dev

# Allow gdb scripts
RUN echo 'add-auto-load-safe-path /app/linux/scripts/gdb/vmlinux-gdb.py' \
  | tee -a /home/dev/.gdbinit

# Set up network share
USER root
RUN echo "" > /etc/exports && \
  echo "/app/share 10.4.4.0/24(rw,fsid=0,insecure,no_subtree_check,async)" \
  | tee -a /etc/exports

# Add helper scripts
COPY helpers/* /app/

USER dev

ENTRYPOINT ["/bin/bash", "compile.sh"]
