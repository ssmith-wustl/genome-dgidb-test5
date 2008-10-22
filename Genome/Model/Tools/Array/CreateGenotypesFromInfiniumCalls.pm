package Genome::Model::Tools::Array::CreateGenotypesFromInfiniumCalls;

use strict;
use warnings;

use Genome;
use Command;
use Text::CSV_XS;
use Sort::Naturally qw( nsort );

class Genome::Model::Tools::Array::CreateGenotypesFromInfiniumCalls {
    is => 'Command',
    has => [
    snp_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Annotation file for the array information being converted",
    },
    genotype_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File of forward strang describing which allele of the probe was detected",
    },
    output_directory =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Directory to place individual files for each header in the file",
    },

    ]
};


sub execute {
    my $self=shift;

    #TODO Some basic file checks

    my $call_href = $self->create_call_file_hash;

    #Store the header information for creating filenames later
    my @filehandles = @{$call_href->{ID}};

    $call_href = $self->convert_to_genotype($call_href);

    #Convert each call into a genotype and write to a new file by chromosome and position
    #create file handles to write out each sample
    my $out_dir = $self->output_directory;
    for my $file (@filehandles) {
        my $filehandle = new IO::File "$out_dir/$file.genotype", "w";
        unless(defined($filehandle)) {
            $self->error_message("Couldn't open filehandle for file: $file");
            return;
        }   
        $file = $filehandle;
    }

    for my $chromosome (nsort keys %$call_href) {
        for my $position (sort {$a <=> $b} keys %{$call_href->{$chromosome}}) {
            my $i;
            for($i = 0; $i < scalar(@{$call_href->{$chromosome}{$position}}); $i++) {
                print {$filehandles[$i]} "$chromosome\t$position\t",${$call_href->{$chromosome}{$position}}[$i],"\n";
            }
        }
    }

    map { $_->close; } @filehandles;
    
    
    return 1;
}

sub create_call_file_hash {
    my $self = shift;
    my $file = $self->genotype_file;
    my %call_hash;

    my $fh = new IO::File "$file", "r";
    unless(defined($fh)) {
        return 0;
    }
    #Skip through the header lines
    while(my $line = $fh->getline) {
        last if $line =~ /\[Data\]/;
    }
    my $expected_calls = undef;

    while(my $line = $fh->getline) {
        $DB::single = 1;
        my ($ID, @calls) = split /\s+/, $line;

        if(defined($expected_calls) && $expected_calls != scalar(@calls)) {
            $self->error_message("Unexpected number of calls");
            return;
        }
        else {
            $expected_calls = scalar(@calls);
        }
        $ID = $ID eq q{} ? 'ID' : $ID;  #make sure that on first line there is an actual label
        $call_hash{$ID} = \@calls; 
    }
    return \%call_hash;
}

sub convert_to_genotype {
    my ($self, $calls) = @_;

    my $csv = new Text::CSV_XS({sep_char => "\t"}); #tab separated
    my $file = $self->snp_file;
    my $afh = new IO::File "$file","r";

    my %new_calls;

    while(my $line = <$afh>) {
        chomp ($line);    

        #File is of the format Name Chr Position

        $csv->parse($line);

        my ($index,$snp_id,$chr,$pos, $score, $snp, $illumina_strand, $cust_strand) = $csv->fields();

        next if($index =~ /^Index$/xi); #skip header
        if(exists($calls->{$snp_id})) {
            #adjust stranding to +/- instead of forward/reverse
            if($cust_strand eq 'TOP') {
                #it's on the - strand in our file
                foreach my $call (@{$calls->{$snp_id}}) {
                    $call =~ tr/ACTGactg/TGACtgac/;
                }
            }
            $new_calls{$chr}{$pos} = $calls->{$snp_id};
            delete $calls->{$snp_id};
        }

    }
    return \%new_calls;
}



1;

sub help_brief {
    "Converts Affy genotype call file into actual base calls"
}
