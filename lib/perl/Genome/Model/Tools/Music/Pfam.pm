package Genome::Model::Tools::Music::Pfam;

use warnings;
use strict;

use IO::File;
use Genome;
use IPC::Run;

=head1 NAME

Genome::Music::Pfam - Adding Pfam annotation to a MAF file

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

class Genome::Model::Tools::Music::Pfam {
    is => 'Command',                       
    has => [ 
    maf_file => {
        is => 'Text', 
        doc => "List of mutations in MAF format",
    },
    output_file => { 
        is => 'Text', 
        doc => "MAF file with Pfam domain column appended",
    },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief { 
    "Add Pfam annotation to a MAF file" 
}

sub help_synopsis {
    return <<EOS
This command adds Pfam Domains to a column at the end of a MAF file.
EXAMPLE:	gmt music pfam --maf-file myMAF.tsv --output-file myMAF.tsv.pfam
EOS
}

sub help_detail {
    return <<EOS 
This tool takes a MAF file, determines the location of each variant therein, and then uses a fast-lookup to retrieve all of the Pfam annotation domains that the variant crosses. A column is appended to the end of the input MAF file called "Pfam_Annotation_Domains" where the results are listed. "NA" is listed if no Pfam domains are found.
EOS
}


=head1 SYNOPSIS

Provides Pfam domains for variants in a MAF file.


=head1 USAGE

      music.pl pfam OPTIONS

      OPTIONS:

      --maf-file		List of mutations in MAF format
      --output-file		Mutations in MAF format with Pfam annotation domain column appended at the end


=head1 FUNCTIONS

=cut

################################################################################

=head2	execute

Initializes a new analysis

=cut

################################################################################

sub execute {

    #parse input arguments
    my $self = shift;
    my $maf_file = $self->maf_file;
    my $output_file = $self->output_file;

    #open MAF file and output file
    my $maf_fh = new IO::File $maf_file,"r";
    my $out_fh = new IO::File $output_file,"w";

    #parse MAF header
    my $maf_header = $maf_fh->getline;
    while ($maf_header =~ /^#/) { 
        $out_fh->print($maf_header);
        $maf_header = $maf_fh->getline;
    }
    my %maf_columns;
    if ($maf_header =~ /Chromosome/) {
        chomp $maf_header;
        #header exists. determine columns containing gene name and sample name.
        my @header_fields = split /\t/,$maf_header;
        for (my $col_counter = 0; $col_counter <= $#header_fields; $col_counter++) {
            $maf_columns{$header_fields[$col_counter]} = $col_counter;
        }
        my $new_header = $maf_header . "\t" . "Pfam_Annotation_Domains" . "\n";
        $out_fh->print($new_header);
    }
    else {
        die "MAF does not seem to contain a header!\n";
    }

    while (my $line = $maf_fh->getline) {
        chomp $line;
        my @fields = split /\t/,$line;
        my $chr = $fields[$maf_columns{'Chromosome'}];
        my $start = $fields[$maf_columns{'Start_position'}];
        my $stop = $fields[$maf_columns{'End_position'}];
        #my $ref = $fields[$maf_columns{'Reference_Allele'}];
        # use environment variable but fall back to reasonable default
        my $db_path = Genome::Sys->dbpath('pfam', 'latest') or die "Cannot find the pfam db path.";
        my $tabix = can_run('tabix') or die "Cannot find the tabix command. It can be obtained from http://sourceforge.net/projects/samtools/files/tabix";
        my $tabix_cmd = "$tabix $db_path/pfam.annotation.gz $chr:$start-$stop - |";
        my %domains;
        open(TABIX,$tabix_cmd) or die "Cannot open() the tabix command. Please check it is in your PATH. It can be installed from the samtools project. $!";
        while (my $tabline = <TABIX>) {
            chomp $tabline;
            my (undef,undef,undef,$csv_domains) = split /\t/,$tabline;
            my @domains = split /,/,$csv_domains;
            for my $domain (@domains) {
                $domains{$domain}++;
            }
        }
        close(TABIX);

        #print output
        my $all_domains = join(",",sort keys %domains);
        my $output_line = "$line\t";
        unless ($all_domains eq "") {
            $output_line .= "$all_domains\n";
        }
        else {
            $output_line .= "NA\n";
        }
        $out_fh->print($output_line);
    }

    return(1);
}

=head1 AUTHOR

The Genome Center at Washington University, C<< <software at genome.wustl.edu> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Genome::Music::Pfam

For more information, please visit http://genome.wustl.edu.

=head1 COPYRIGHT & LICENSE

Copyright 2010 The Genome Center at Washington University, all rights reserved.

This program is free and open source under the GNU license, the BSD license, and the MIT license.

=cut

1; # End of Genome::Music::Pfam
