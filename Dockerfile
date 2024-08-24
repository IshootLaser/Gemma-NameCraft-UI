FROM ghcr.io/cirruslabs/flutter:3.24.0

RUN addgroup --system appgroup && adduser --system appuser --ingroup appgroup
### Copying the files to the /app/ directory and setting it as the working directory.
#
RUN mkdir /app/
COPY . /app/
WORKDIR /app/
### This command provides detailed information about the Flutter installation, environment, and any missing dependencies.
### And it helps ensure that the necessary tools and configurations are in place for building Flutter applications.
#
RUN flutter clean
RUN flutter doctor -v
### This command enables web support in the Flutter SDK.
### It configures the Flutter environment to include web-specific libraries and dependencies required for building Flutter web applications.
#
RUN flutter config --enable-web
### This command builds the Flutter web application in release mode.
### It generates the necessary files and assets for running the application on the web.
### The --web-renderer=auto flag allows Flutter to automatically choose the appropriate web renderer (HTML or Canvas) based on the platform and browser capabilities.
#
RUN flutter build web --release --web-renderer=auto
#USER appuser:appgroup