#!/usr/bin/env perl

use Web::Simple 'Genome::Model::Command::Services::WebApp::File';
use MIME::Base64;

package Genome::Model::Command::Services::WebApp::File;

our $loaded = 0;
sub load_modules {
    return if $loaded;
    eval "
        use above 'Genome';
        use Workflow;
        use HTML::Tags;
        use Plack::MIME;
        use Plack::Util;
        use Plack::Request;
        use Cwd;
        use HTTP::Date;
        use JSON;
        use UR::Object::View::Default::Xsl qw/type_to_url url_to_type/;
    ";
    if ($@) {
        die "failed to load required modules: $@";
    }

    # search's callbacks are expensive, web server can't change anything anyway so don't waste the time
    Genome::Search->unregister_callbacks('UR::Object');
}

sub dispatch_request {

#    sub ( POST + /view/x/subject-upload + *file= ) {
    sub ( POST + /view/x/subject-upload + %* + *file= )  {

        load_modules();
        my ($self, $params, $file, $env) = @_;

        my $pathname = $file->path;

        my $c;
        {   open(my $fh, $pathname);
            undef $/;
            $c = <$fh>;
            close($fh);
        }
    
        my $base64 = MIME::Base64::encode_base64($c);

        my $task_params_json = encode_json( { 
            nomenclature => $params->{'nomenclature'},
            subclass_name => $params->{'subclass_name'},
            content => $base64 });

        my $task_params = {
            command_class => 'Genome::Subject::Command::Import',
            user_id       => $ENV{'REMOTE_USER'} || 'genome@localhost',
            params        => $task_params_json
        };

        my $task; eval {
            $task = Genome::Task->create(%$task_params);
            UR::Context->commit();
        };

        my $code; my $body = {};
        if ($@ || !$task) {
            $code = 200; # OK (didnt work)
            $body->{'error'} = $@ || 'Couldnt create a task with params: ' . Data::Dumper::Dumper $task_params;
        } else {
            $code = 201; # CREATED
            $body->{'id'} = $task->id();
        }

        return [301, [ 'Location' => "/view/genome/task/status.html?id=" . $task->id() ], [encode_json($body)]];
    }
};

Genome::Model::Command::Services::WebApp::File->run_if_script;



