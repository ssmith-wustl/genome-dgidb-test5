#!/usr/bin/env perl

use Web::Simple 'Genome::Model::Command::Services::WebApp::File';

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

        my $task_params_json = encode_json( { 
            nomenclature => $params->{'nomenclature'},
            subclass_name => $params->{'subclass_name'},
            content => $c });

        my $task_params = {
            command_class => 'Genome::Subject::Command::Import',
            user_id       => 'tigerwoods',
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

        return [201, [ 'Content-type' => "text/plain" ], [encode_json($body)]];
    }
};

Genome::Model::Command::Services::WebApp::File->run_if_script;



