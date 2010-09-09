package Genome::Model::Command::Services::WebApp::Cache;

use strict;
use warnings;

use Data::Dumper;

use Plack::Util;
use Digest::MD5;
use Cache::Memcached;
use Storable qw/freeze thaw/;

our $environment = 'local';
our %servers = ('prod' => 'imp:11211', 'dev' => 'aims-dev:11211', 'local' => 'localhost:11211');
our $cache_timeout = 0;
our $lock_timeout = 0;
our $server;

sub environment {
    my $class = shift;
    $environment = shift;
    undef $server;
}

sub server {
    my $class = shift;

    unless (defined $server) {
        $server = Cache::Memcached->new({
            servers => [$servers{$environment}],
            debug => 0,
            compress_threshold => 10_000
        });
    }
    return $server;
}

sub hash_url {
    my $class = shift;
    my $url = shift;

    return Digest::MD5::md5_base64($url);
}

sub cache_key_for_url {
    my $class = shift;
    my $url = shift;

    return 'genome_wac:' . $class->hash_url($url);
}

sub lock_key_for_url {
    my $class = shift;
    my $url = shift;

    return 'genome_lock:' . $class->hash_url($url);
}

sub get {
    my $class = shift;
    my $url = shift;

    return $class->server->get($class->cache_key_for_url($url));
}

sub set {
    my $class = shift;
    my $url = shift;
    my $value = shift;

    return $class->server->set($class->cache_key_for_url($url),$value,$cache_timeout);
}

sub lock {
    my $class = shift;
    my $url = shift;

    return $class->server->add($class->lock_key_for_url($url),$$,$lock_timeout);
}

sub unlock {
    my $class = shift;
    my $url = shift;

    return $class->server->delete($class->lock_key_for_url($url));
}

sub getlock {
    my $class = shift;
    my $url = shift;

    return $class->server->get($class->lock_key_for_url($url));
}

sub delete {
    my $class = shift;
    my $url = shift;

    return $class->server->delete($class->cache_key_for_url($url));
}


sub {
    my $class = __PACKAGE__;
    my ($env, $ajax_refresh) = @_;

    my $url = $env->{'PATH_INFO'};
    if (exists $env->{'QUERY_STRING'} && defined $env->{'QUERY_STRING'}) {
        $url .= '?' . $env->{'QUERY_STRING'};
    }

    if ($ajax_refresh) {
        my $rest_app = $Genome::Model::Command::Services::WebApp::Main::app{'Rest.psgi'};

        if ($class->lock($url)) {

            my $resp = Plack::Util::run_app $rest_app, $env;
            if ($resp->[0] == 200 && ref($resp->[2]) eq 'ARRAY') {
                if (!$class->set($url,freeze($resp))) {
                    $class->unlock($url);

                    return [
                        500,
                        [ 'Content-type' => 'text/html' ],
                        [ 'Memcached is down' ]
                    ];
                }
            }
            $class->unlock($url);
        } else {
            my $v;
            do {
                $v = $class->getlock($url);
                sleep 1 if $v;
            } while ($v);
        }
 
        return [
            200,
            [ 'Content-type' => 'text/html' ],
            [ 'Done' ]
        ];
    } else {

        if ($env->{'PATH_INFO'} !~ /html$/) {
            my $rest_app = $Genome::Model::Command::Services::WebApp::Main::app{'Rest.psgi'};
            my $resp = Plack::Util::run_app $rest_app, $env;

            return $resp;
        }

        my $v = $class->get($url);

        my $no_cache = $env->{'HTTP_CACHE_CONTROL'} || $env->{'HTTP_PRAGMA'};

        if (defined $v && $no_cache ne 'no-cache') {
            my $s = thaw($v);
            return $s;
        } else {
            my $content = q[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <!--template: status/root.xsl:match "/"-->
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Cache miss</title>
    <link rel="shortcut icon" href="/res/img/gc_favicon.png" type="image/png" />
    <link rel="stylesheet" href="/res/css/blueprint/screen.css" type="text/css" media="screen, projection" />
    <link rel="stylesheet" href="/res/css/blueprint/print.css" type="text/css" media="print" />
    <link rel="stylesheet" href="/res/css/master.css" type="text/css" media="screen, projection" />
    <link rel="stylesheet" href="/res/css/buttons.css" type="text/css" media="screen, projection" />
    <link rel="stylesheet" href="/res/css/icons.css" type="text/css" media="screen, projection" />
    <link rel="stylesheet" href="/res/css/forms.css" type="text/css" media="screen, projection" />
    <link type="text/css" href="/res/css/jquery-ui.css" rel="stylesheet" />
    <link href="/res/css/jquery-ui-overrides.css" type="text/css" rel="stylesheet" media="screen, projection" />
  <script type="text/javascript" src="/res/js/pkg/jquery.js"></script>

  <script type="text/javascript">
   (function($) {
      var cache = [];
      // Arguments are image paths relative to the current page.
      $.preLoadImages = function() {
        var args_len = arguments.length;
        for (var i = args_len; i--;) {
          var cacheImage = document.createElement('img');
          cacheImage.src = arguments[i];
          cache.push(cacheImage);
        }
      }


     $(document).ready(function() {

        $.preLoadImages("/res/img/spinner.gif");

        $("#ajax_status")
        .addClass('success')
        .bind("ajaxSend", function(){
            $(this).removeClass('success error').addClass('loading').html('Loading').show();
        })
        .bind("ajaxSuccess", function(){
            $(this).removeClass('loading').addClass('success').html('Success').hide('slow');
        })
        .bind("ajaxError", function(){
            $(this).removeClass('loading').addClass('error').html('Error');
        })
        .hide();

       $.ajax({
         url: '/viewajax] . $url . q[',
         success: function(data) {
           location.reload();
         }
       });
     });

   })(jQuery)
  </script>
 </head>
 <body>
  <div class="page">
    <div class="header rounded-bottom gradient-grey shadow">
      <div class="container">
        <div class="title span-24 last app_error_32">
          <h1>Cache miss</h1>
        </div>
      </div>
    </div>
    <div class="content rounded shadow" style="background-color: #FAA">
      <div class="container">
      <div class="span-24 last">
        <div class="rounded" style="background: #FFF; margin-bottom: 10px;">
          <div class="padding10">
            <p>Regenerating view from the object model, please be patient.</p>
            <div id="ajax_status"/>
          </div>
        </div>
      </div>
    </div>
  </div>
 </body>
</html>
];

            return [
                200,
                [ 'Content-type' => 'text/html' ],
                [ $content ]
            ];
        }
    }
};
