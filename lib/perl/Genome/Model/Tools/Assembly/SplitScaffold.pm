package Genome::Model::Tools::Assembly::SplitScaffold;

use strict;
use warnings;

use Genome;
use Cwd;

class Genome::Model::Tools::Assembly::SplitScaffold
{
    is => 'Command',
    has => 
    [
        ace_file => {
            type => "String",
            optional => 0,
            doc => "This is the input ace file"
        }, 
        split_contig => {
            type => "String",
            optional => 0,
            doc => "This is the name of the contigs which will be the last contig in the left scaffold",
        },
	    out_file_name => {
            type => "String",
            optional => 0,
		    doc => "This is the name of the output file",
	    },	    
    ]
};

sub help_brief {
    ""
}

sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    split-scaffold --ace-file=in.ace --split-contig=Contig0.8 --out-file-name=out.ace
EOS
}

sub get_contig_names
{
    my ($self, $ace_file_name) = @_;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($ace_file_name);
    $self->error_message("There was an error opening ace file $ace_file_name for reading.") and die unless defined $fh;
    my @contig_names;
    while(my $line = <$fh>)
    {
        if($line =~ /^CO /)
        {
            my @tokens = split /\s+/,$line;
            push @contig_names, $tokens[1];            
        }
    }
    return \@contig_names;
}

sub execute
{
    my $self = shift;
    $DB::single = 1;
    my $ace_file = $self->ace_file;
    my $split_contig_name = $self->split_contig;
    my $out_file_name = $self->out_file_name;

    $self->error_mesage("Input ace file $ace_file does not exist\n") and return unless (-e $ace_file);
    
    my $contig_names = $self->get_contig_names($ace_file);
    my ($scaffold_name, $contig_num, $suffix);
    ($scaffold_name, $contig_num) = $split_contig_name =~ /(Contig\d+)\.(\d+)/;
    ($suffix) = $split_contig_name =~ /Contig\d+\.\d+(\D+)/;
    $suffix = '' unless defined $suffix;
    my @scaffold_contigs = grep 
    { 
        my $temp; 
        my $result = $_ =~ /$scaffold_name\.\d+$suffix/;
        ($temp) = $_ =~  /$scaffold_name\.\d+$suffix(\D+)/;#check to make sure that we don't count contigs with different extensions as belonging to the same scaffold.
        ($result && !(defined $temp && length $temp));
    } @{$contig_names};
    
    unless (@scaffold_contigs)
    {
        print "Couldn't find scaffold that $split_contig_name belongs to.\n";
        print "It appears that scaffold $scaffold_name.XX$suffix does not exist.\n";
        return;    
    }
    my %scaffold_contigs;
    foreach my $contig (@scaffold_contigs) 
    { 
        my ($curr_scaffold_name, $curr_contig_num) = $contig =~ /(Contig\d+)\.(\d+)/; 
        if($curr_contig_num <= $contig_num)
        {
            $scaffold_contigs{$contig} = $contig.'a';
        }
        else
        {
            $scaffold_contigs{$contig} = $contig.'b';
        }
    }
    
    #do a search and replace for all contig names above
    my $fh = IO::File->new($ace_file);
    my $out_fh = IO::File->new(">$out_file_name");
    while(my $line = <$fh>)
    {   
        if($line =~ /Contig/)
        { 
            foreach my $sub_contig (keys %scaffold_contigs)
            {
                if($line =~/$sub_contig\W+/)
                {                
                    $line =~ s/$sub_contig/$scaffold_contigs{$sub_contig}/g;
                    last;            
                }            
            }
        }
        $out_fh->print($line);
    }
    return 1;
}


1;





