const troubleshootingPage =
    'https://github.com/rutikeyone/cobalt/blob/main/docs/TROUBLESHOOTING.md';

String troubleshootingLink(Object error) =>
    'See $troubleshootingPage#${error.runtimeType.toString().toLowerCase()}';
