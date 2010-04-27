#!/gsc/bin/perl

use Web::Simple 'Genome::Model::Command::Services::WebApp::Main';

package Genome::Model::Command::Services::WebApp::Main;

use Data::Dumper;
use Plack::Util;
use above 'Genome';

my $psgi_path = Genome::Model::Command::Services::WebApp->psgi_path;

my %app = map { $_ => load_app($_) } qw/
  Rest.psgi
  Redirect.psgi
  Resource.psgi
  404Handler.psgi
  Dump.psgi
  /;

## Utility functions
sub load_app {
    Plack::Util::load_psgi( $psgi_path . '/' . shift );
}

sub redispatch_psgi {
    my ( $psgi_app, @args ) = @_;
    __PACKAGE__->_build_dispatcher(
        {
            call => sub {
                shift;
                my ( $self, $env ) = @_;
                $psgi_app->( $env, @args );
              }
        }
    );
}

sub redirect_to {
    redispatch_psgi( $app{'Redirect.psgi'}, shift );
}

## Web::Simple dispatcher for all apps
dispatch {
    ## make 404's pretty by sending them to 404Handler.psgi
    response_filter {
        my $resp = $_[1];

        if ( ref($resp) eq 'ARRAY' && $resp->[0] == 404 ) {
            return redispatch_psgi( $app{'404Handler.psgi'}, $resp->[2] );
        }

        return $resp;
    },
      ## send /view without a trailing slash to /view/
      ## although thats probably a 404
      sub (/view) {
        redispatch_to "/view/";
      },

      # let Rest.psgi handle this
      sub (/view/...) {
        redispatch_psgi $app{'Rest.psgi'};
      },

      subdispatch sub (/static/...) {
        [
            ## look for static files related to a view
            sub (/Genome/**) {
                redispatch_psgi $app{'Dump.psgi'};
            },
            ## look for anything else on the filesystem
            sub () {
                redispatch_psgi $app{'Resource.psgi'};
              }
        ];
      },

      ## dump the psgi environment, for testing
      sub (/dump/...) {
        redispatch_psgi $app{'Dump.psgi'};
      },

      ## send the browser to the finder view of Genome
      sub (/) {
        redirect_to "/view/Genome/default.html";
      }
};

Genome::Model::Command::Services::WebApp::Main->run_if_script;
