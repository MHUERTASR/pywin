FROM scottyhardy/docker-wine:latest

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    XDG_RUNTIME_DIR=/tmp/runtime-root \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=;gdiplus=native,builtin" \
    PYTHONUTF8=1 \
    PYTHONIOENCODING=utf-8 \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    WINEPATH="C:\Python311;C:\Python311\Scripts;C:\Windows\system32;C:\Windows"

WORKDIR /root

RUN mkdir -p /tmp/runtime-root && chmod 700 /tmp/runtime-root

# 1. Instalar dependencias de Linux
RUN apt-get update && \
    apt-get install -y wget curl cabextract file \
    cups \
    cups-client \
    printer-driver-cups-pdf && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/PDF_OUTPUT && \
    chmod 777 /root/PDF_OUTPUT && \
    sed -i 's|Out ${HOME}/PDF|Out /root/PDF_OUTPUT|g' /etc/cups/cups-pdf.conf && \
    sed -i 's|#AnonDirName /var/spool/cups-pdf/ANONYMOUS|AnonDirName /root/PDF_OUTPUT|g' /etc/cups/cups-pdf.conf

RUN service cups start && \
    lpadmin -p Virtual_PDF -v cups-pdf:/ -E -P /usr/share/ppd/cups-pdf/CUPS-PDF_opt.ppd && \
    lpadmin -d Virtual_PDF && \
    service cups stop

# 2. Instalar librerías base de Windows (Winetricks)
RUN winetricks --self-update && \
    xvfb-run -a winetricks -q --force vcrun2019 corefonts msxml6 gdiplus

# 3. Instalar Office 2010
RUN curl -o /root/Office2010.exe -L https://github.com/xeden3/docker-office-python-core/releases/download/v0.0/Office2010_4in1_20210124.exe && \
    curl -o /root/.wine/drive_c/windows/Fonts/simsun.ttc -L https://github.com/xeden3/docker-office-python-core/releases/download/v0.0/simsun.ttc && \
    xvfb-run -a bash -c '\
    winecfg -v win7 && \
    wineserver -w && \
    wine /root/Office2010.exe /S && \
    wineserver -w' && \
    rm /root/Office2010.exe

# 4. Descargar Python
RUN wget https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe -O /root/python-installer.exe

# 5. Instalar Python 3.11
RUN xvfb-run -a bash -c '\
    echo "Configurando Windows 10..." && \
    winecfg -v win10 && \
    wineserver -w && \
    echo "Instalando Python..." && \
    wine /root/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1 TargetDir="C:\Python311" Include_doc=0 && \
    wineserver -w' && \
    rm /root/python-installer.exe

# 6. Instalar dependencias Pip y PyWin32
RUN xvfb-run -a bash -c '\
    wine python -m pip install --upgrade pip setuptools wheel pywin32 && \
    wineserver -w'

# 7. Post-install y Registro de Excel
RUN cd /root/.wine/drive_c/Python311/Scripts && \
    xvfb-run -a bash -c '\
    wine python pywin32_postinstall.py -install && \
    wine "C:\Program Files (x86)\Microsoft Office\Office14\EXCEL.EXE" /regserver || true && \
    wineserver -w' && \
    rm -rf /root/.wine/drive_c/users/root/Temp/*

CMD service cups start && tail -f /dev/null