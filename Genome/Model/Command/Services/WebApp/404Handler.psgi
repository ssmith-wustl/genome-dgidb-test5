
package Genome::Model::Command::Services::WebApp::404Handler;

use strict;
use warnings;

sub {
    my ( $env, $content ) = @_;

    my $string = join( "\n", @$content );
    my $doc = <<"    HTML";
<html>
  <head>
    <title>Not Found</title>
  </head>
  <body>
    <h1>Not Found</h1>
    <code>$string</code>
  </body>
</html>
    HTML

    [ 404, [ 'Content-type', 'text/html' ], [$doc] ];
};
