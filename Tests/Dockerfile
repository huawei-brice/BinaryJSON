# A little dockerfile to compile BinaryJSON on Ubuntu to run tests.
# Built (from root directory) with `docker build -t danappelxx/binaryjson -f Tests/Dockerfile .`

FROM zewo/swiftdocker:0.4.0

### libbson
# Install build dependencies
RUN apt-get update
RUN apt-get install -y git-core automake autoconf libtool gcc

# Download release tarball
RUN wget https://github.com/mongodb/libbson/releases/download/1.3.5/libbson-1.3.5.tar.gz
RUN tar xzf libbson-1.3.5.tar.gz

WORKDIR /libbson-1.3.5/

# Compile libbson
RUN ./configure
RUN make && make install
RUN ldconfig

### BinaryJSON
WORKDIR /BinaryJSON/

# Copy files
ADD ./Package.swift /BinaryJSON/
ADD ./Sources /BinaryJSON/Sources
ADD ./Tests /BinaryJSON/Tests

# Build it
RUN swift build -Xcc -I/usr/local/include/libbson-1.0 -Xlinker -L/usr/local/lib

### To run tests, start this container with /bin/bash and run `swift test`.
