package Genome::Model::Tools::Assembly::DoMerges; 

use IO::File;
use strict;
use warnings;
use Workflow::Simple;

class Genome::Model::Tools::Assembly::DoMerges {
    is => 'Command',
    has => [
        ace_directory => {
            is => 'String',
            shell_args_position => 1,
            is_optional => 0,
            doc => 'the directory containing the ace files (usually edit_dir)',
        },
        merge_list => {
            is => 'String',
            shell_args_position => 2,
            is_optional => 0,
            doc => 'the list of joins',
        },
    ],    
    doc => 'Takes a merge list as input and performs joins'
};

sub check_multiple_versions
{
    my ($self, $ace_directory) = @_;
    
    #filter out any non ace files
    
    my @ace_files = `ls $ace_directory/*scaffold*.ace*`;
    my @versioned_ace_files;
    @versioned_ace_files = grep { /.+\.ace\.\d+$/ } @ace_files;
    @ace_files = grep { /.+\.ace$/ } @ace_files;
    @ace_files = (@ace_files,@versioned_ace_files);

    return 1 if(scalar @versioned_ace_files);
    
    return 0;
}

sub execute
{
    my $self = shift;
    my $ace_directory = $self->ace_directory; 
    my $merge_list = $self->merge_list;
    
    $self->warning_message("Versioned ace files detected.  The merging toolkit only works on files ending in .*.ace, other ace files will be ignored\n") if($self->check_multiple_versions($ace_directory));
    my $fh = IO::File->new($merge_list);
    my @ace_files = `ls $ace_directory/*scaffold*.ace`;
    #filter out singleton acefiles
    @ace_files = grep { !/singleton/ } @ace_files;  
    
    $self->error_message( "There are no valid ace files in $ace_directory\n") and return unless (scalar @ace_files);  
    chomp @ace_files;
    my $mod = scalar @ace_files;
    my ($prefix) = $ace_files[0] =~ /(.*)\d+\.ace/;
    sub get_num
    {
        my ($name) = @_;
        my ($ctg_num) = $name =~ /Contig(\d+)\.\d+/;
	    ($ctg_num) = $name =~ /Contig(\d+)/ if(!defined $ctg_num);

        return $ctg_num;
    }
    my @lines = <$fh>;
    chomp @lines;
    my %list;
    foreach (@lines)
    {
	    my @tokens = split;
	    $list{$tokens[0]} = [$tokens[0], $tokens[1]];
    }
    foreach (keys %list)
    {
	    next if(!exists $list{$_});
	    my @temp = @{$list{$_}};
	    my $last_element = $temp[@temp-1];
	    while(exists $list{$last_element})
	    {
		    shift @{$list{$last_element}};
		    push @{$list{$_}}, @{$list{$last_element}};

		    @temp = @{$list{$last_element}};
		    delete $list{$last_element};
		    $last_element = $temp[@temp-1];

	    } 
    }

    my @contigs_list;
    foreach (values %list)
    {
	    my @contigs = @{$_};
	    my $args;
	    foreach (@contigs)
	    {
		    $args.= $prefix.get_num($_)%$mod.".ace $_ ";
	    }
	    my $cmd = "cmt.pl $args";
        print $args,"\n";
        push @contigs_list,$args;

    }
    
    
    my $w = Workflow::Operation->create(
        name => 'do merges',
        operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::Assembly::MergeContigs'),
    );
    
    $w->parallel_by('contigs');
    
    $w->log_dir('/gscmnt/936/info/jschindl/MISCEL/wflogs');
    
    $w->validate;
    if(!$w->is_valid)
    {
        $self->error_message("There was an error while validating parallel merge workflow.\n") and return;
    }
      
    my $result = Workflow::Simple::run_workflow_lsf(
        $w,
        'contigs' => \@contigs_list,        
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
    
    print "Merges completed successfully\n";
    return 1;
}

1;
