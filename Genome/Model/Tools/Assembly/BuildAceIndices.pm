package Genome::Model::Tools::Assembly::BuildAceIndices; 

use IO::File;
use strict;
use warnings;
use Workflow::Simple;
use Genome::Assembly::Pcap::Ace;

class Genome::Model::Tools::Assembly::BuildAceIndices {
    is => 'Command',
    has => [
        ace_directory => {
            is => 'String',
            shell_args_position => 1,
            is_optional => 1,
            doc => 'the directory containing the ace files (usually edit_dir)',
        },
        ace_file => {
            is => 'String',
            shell_args_position => 3,
            is_optional => 1,
            is_input => 1,
            doc => 'the ace file that we are indexing',      
        },
        cc => {
            is => 'Boolean',
            shell_args_position => 2,
            is_optional => 1,
            default_value => 0,
            is_input => 1,
            doc => 'this flushes any old cached data from the mysql database for the ace file(s)'
        },
    ],    
    doc => 'Indexes ace files'
};

sub check_multiple_versions
{
    my ($self, $ace_directory) = @_;
    
    #filter out any non ace files
    
    my @ace_files = `ls $ace_directory/*.ace*`;
    my @versioned_ace_files;
    @versioned_ace_files = grep { /.+\.ace\.\d+$/ } @ace_files;
    @ace_files = grep { /.+\.ace$/ } @ace_files;
    @ace_files = (@ace_files,@versioned_ace_files);

    return 1 if(scalar @versioned_ace_files);
    
    return 0;
}

sub execute
{
    $DB::single=1;
    my $self = shift;
    my $ace_directory = $self->ace_directory; 
    my $cc = $self->cc;
    my $ace_file = $self->ace_file;
    if($self->ace_directory)
    {
        $self->warning_message("Versioned ace files detected.  The merging toolkit only works on files ending in .*.ace, other ace files will be ignored\n") if($self->check_multiple_versions($ace_directory));
        my @ace_files = `ls $ace_directory/*.ace`;
    
        $self->error_message( "There are no valid ace files in $ace_directory\n") and return unless (scalar @ace_files);  
        chomp @ace_files;
    
        my $w = Workflow::Operation->create(
            name => 'build indices',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::Assembly::BuildAceIndices'),
        );

        $w->parallel_by('ace_file');

        $w->log_dir('/gscmnt/936/info/jschindl/MISCEL/wflogs');

        $w->validate;
        if(!$w->is_valid)
        {
            $self->error_message("There was an error while validating parallel merge workflow.\n") and return;
        }

        my $result = Workflow::Simple::run_workflow_lsf(
            $w,
            'ace_file' => \@ace_files,        
            'cc' => $cc,
        );

        unless($result)
        {
            # is this bad?
            foreach my $error (@Workflow::Simple::ERROR) {

                $self->error_message( join("\t", $error->dispatch_identifier(),
                                                 $error->name(),
                                                 $error->start_time(),
                                                 $error->end_time(),
                                                 $error->exit_code(),
                                                ) );

                $self->error_message($error->stdout());
                $self->error_message($error->stderr());

            }
            return;

        }
    }
    elsif($ace_file && -e $ace_file)
    {
        my $ao = Genome::Assembly::Pcap::Ace->new(input_file => $ace_file,using_db => 1,db_type => 'mysql',cc=>1);
        $ao->dbh->disconnect;
        $ao=undef;
    }    

    return 1;
}

1;
