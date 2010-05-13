
package Genome::Model::Command::Services::WebApp::404Handler;

use strict;
use warnings;

sub {
    my ( $env, $content ) = @_;

    my $string = join( "\n", @$content );
    my $doc = <<"    HTML";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>Analysis Dashboard v1.0</title>
<link rel="shortcut icon" href="/res/img/gc_favicon.png" type="image/png">
<link rel="stylesheet" href="/res/css/master.css" type="text/css" media="screen">
<style type="text/css" media="screen">
          div.container,
          div.background {
               width: 770px;
          }

          pre {
               white-space: pre-wrap; /* css-3 */
               white-space: -moz-pre-wrap !important; /* Mozilla, since 1999 */
               white-space: -pre-wrap; /* Opera 4-6 */
               white-space: -o-pre-wrap; /* Opera 7 */
               word-wrap: break-word; /* Internet Explorer 5.5+ */
          }
        </style>
</head>
<body><div class="container"><div class="background" style="border-color: #7d000f">
<h1 class="page_title" style="background-color: #a30013; border-color: #7d000f;">Analysis Dashboard v1.0</h1>
<div class="page_padding">
<h2 style="color: #a30013">Error Encountered:</h2>

<p><pre>
$string
</pre></p>
</div>
</div></div></body>
</html>
    HTML

    [ 404, [ 'Content-type', 'text/html' ], [$doc] ];
};
