package Genome::Model::Tools::Hgmi::RrnaScreen;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use IPC::Run;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
        has => [

            'sequence_set_id' => { is => 'String',
                    doc => "sequence set id of organism",
            },
            'dev' => { is => 'Boolean',
                       doc => "development flag",
                       is_optional => 1,
                       default => 0,
            },
            'rrna_database' => { is => 'String',
                    doc => "rrna database",
                    is_optional => 1,
            },
    ],
);

sub help_brief
{
    "Runs the rrna screen after everything has been finished.";
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
need to put help synopsis here
EOS
}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
RNAMMER usually has trouble detecting rrna gene fragments in assemblies,
thus this tool for screening gene sets for genes that are really rrna 
fragments.  These genes will get tagged in mgap as 'Dead'.
EOS
}


#sub create
#{
#    my $self = shift;
#
#    return 1;
#}

sub execute
{
    my $self = shift;

    my @rrnascreen = (
        '/gsc/scripts/bin/bap_rrna_screen',
        '--sequence-set-id',
        $self->sequence_set_id,

        );

    if($self->dev)
    {
        push(@rrnascreen,'--dev');
    }

    my ($stdout, $stderr);

    IPC::Run::run(
        \@rrnascreen,
        '>',
        \$stdout,
        '2>',
        \$stderr,
      ) or croak "can't run rrna screen\n$stderr";

    return 1;
}


1;
