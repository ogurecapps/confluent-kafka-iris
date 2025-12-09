FROM intersystems/iris-community:latest-cd

RUN python3 -m pip install --target /usr/irissys/mgr/python confluent-kafka

USER root
WORKDIR /opt/iris

RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/iris
COPY deployment/ .
RUN chmod +x ./irissession.sh

USER ${ISC_PACKAGE_MGRUSER}

COPY src src

SHELL ["./irissession.sh"]

RUN \
  do $SYSTEM.OBJ.Load("./Installer.cls", "ck") \
  set sc = ##class(App.Installer).Setup()

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]