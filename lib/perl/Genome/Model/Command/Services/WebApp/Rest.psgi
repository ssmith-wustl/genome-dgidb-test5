#!/gsc/bin/perl

use Web::Simple 'Genome::Model::Command::Services::WebApp::Rest';

package Genome::Model::Command::Services::WebApp::Rest;

use above 'Genome';
use Workflow;
use Plack::MIME;
use Plack::Util;
use Cwd;
use HTTP::Date;

use UR::Object::View::Default::Xsl qw/type_to_url url_to_type/;

my $res_path = Genome::Model::Command::Services::WebApp->res_path;

dispatch {

    sub (GET + /**/*/* + .*) {
        my ( $self, $class, $perspective_toolkit, $filename, $extension ) = @_;

        if ( $class =~ /\./ ) {

            # matched on some multi-part path after the perspective_toolkit
            if ( $class =~ s/\/(.+?)$//g ) {
                $filename            = $perspective_toolkit . '/' . $filename;
                $perspective_toolkit = $1;

                if ( $perspective_toolkit =~ s/\/(.+)$//g ) {
                    $filename = $1 . '/' . $filename;
                }
            } else {

                # let some other handler deal with this, i cant parse it
                return;
            }
        } elsif ( index( $perspective_toolkit, '.' ) < 0 ) {

            # doesn't have a period in it?  probably didnt want us to match
            return;
        }

        $class = url_to_type($class);
        my ( $perspective, $toolkit ) = split( /\./, $perspective_toolkit );
        my $mime_type = Plack::MIME->mime_type(".$extension");

        my $view_class = UR::Object::View->_resolve_view_class_for_params(
            subject_class_name => $class,
            perspective        => $perspective,
            toolkit            => $toolkit
        );

        unless ($view_class) {
            return [
                404,
                [ 'Content-type', 'text/plain' ],
                ["No view for $class $perspective $toolkit"]
            ];
        }

        my $base_dir = $view_class->base_dir;
        unless ( -d $base_dir ) {
            return [
                404,
                [ 'Content-type', 'text/plain' ],
                ["No resource directory for $view_class"]
            ];
        }

        my $full_path = $base_dir . '/' . $filename;

        unless ( -e $full_path ) {
            return [
                404,
                [ 'Content-type', 'text/plain' ],
                ["No resource $filename for $view_class"]
            ];
        }

        open my $fh, "<:raw", $full_path
          or return [ 403, [ 'Content-type', 'text/plain' ], ['forbidden'] ];

        my @stat = stat $full_path;

        Plack::Util::set_io_path( $fh, Cwd::realpath($full_path) );

        ## Plack should have set binmode for us, workaround here because it's dumb.
        if ( $ENV{'GATEWAY_INTERFACE'} ) {
            binmode STDOUT;
        }

        return [
            200,
            [
                'Content-type'   => $mime_type,
                'Content-Length' => $stat[7],
                'Last-Modified'  => HTTP::Date::time2str( $stat[9] )
            ],
            $fh
        ];
      },

      sub (GET + /**/* + .* + ?@*) {
        my ( $self, $class, $perspective, $toolkit, $args ) = @_;

        $class = url_to_type($class);
        $perspective =~ s/\.$toolkit$//g;

        my $mime_type = Plack::MIME->mime_type(".$toolkit");

        for my $key ( keys %$args ) {
            if ( index( $key, '_' ) == 0 ) {
                delete $args->{$key};
                next;
            }
            my $value = $args->{$key};

            if ( $value and scalar @$value eq 1 ) {
                $args->{$key} = $value->[0];
            }
        }

        my @matches = $class->get(%$args);
        unless (@matches) {
            return [ 404, [ 'Content-type', 'text/plain' ],
                ['No object found'] ];
        }
        die 'matched too many; list not yet supported' unless ( @matches == 1 );

        my %view_args = (
            perspective => $perspective,
            toolkit     => $toolkit
        );

        if ( $toolkit eq 'xsl' || $toolkit eq 'html' ) {
            $view_args{'xsl_root'} =
              Genome->base_dir . '/xsl';    ## maybe move this to $res_path?
            $view_args{'xsl_path'} = '/static/xsl';

            #            $view_args{'rest_variable'} = '/view';

            $view_args{'xsl_variables'} = {
                rest      => '/view',
                resources => '/view/genome/resource.html'
            };
        }

        my $view;
        eval { $view = $matches[0]->create_view(%view_args); };

        if ( $@ && !$view ) {
            $view_args{'desired_perspective'} = $perspective;
            $view_args{'perspective'}         = 'default';

            eval { $view = $matches[0]->create_view(%view_args); };
            if ($@) {
                return [
                    404, [ 'Content-type', 'text/plain' ],
                    ['No view found']
                ];
            }
        }

        die 'no_view' unless ($view);

        my $content = $view->content();

        #        UR::Context->rollback;
        #        UR::Context->clear_cache;

        [ 200, [ 'Content-type', $mime_type ], [$content] ];
      }
};

Genome::Model::Command::Services::WebApp::Rest->run_if_script;
