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
    # snp_file =>
    # {
    #     type => 'String',
    #     is_optional => 0,
    #     doc => "Annotation file for the array information being converted",
    # },
    genotype_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File of forward strand describing which allele of the probe was detected",
    },
    output_directory =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Directory to place individual files for each header in the file",
    },
    ucsc_array_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => 'File from UCSC indicating which strand and alleles the Infinium platform probes'
    },
    #probe_file => 
    #{
    #    type => 'String',
    #    is_optional => 0,
    #    doc => 'File from illumina with probe sequences and information on stranding'
    #},
    ]
};


sub execute {
    my $self=shift;

    #TODO Some basic file checks
    $DB::single = 1;
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
        chomp $line;
        my ($ID, @calls) = split /[\t,]/, $line;
        map {$_ =~ s/(\D+)\|.*$/$1/g;} @calls;

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

sub create_probe_hash {
    my ($self) = @_;

    my $file = $self->probe_file;
    my $fh = new IO::File "$file", "r";
    unless(defined($fh)) {
        return 0;
    }

    my %probe;

    while(my $line = $fh->getline) {
        last if $line =~ /^\[Assay\]/;    
    }

    #skip final header line
    $fh->getline;
    
    while(my $line = $fh->getline) {
        my ($illumina_id, $name, $illumina_strand, $alleles) = split /,/, $line;
        $probe{$name} = { id => $illumina_id,
            strand => substr($illumina_strand, 0, 1),
            alleles => $alleles,
        };
    }

    return \%probe;
}

sub convert_to_genotype {
    my ($self, $calls) = @_;

    my $csv = new Text::CSV_XS({sep_char => "\t"}); #tab separated
    my $file = $self->ucsc_array_file;
    my $afh = new IO::File "$file","r";

    my %new_calls;

    while(my $line = <$afh>) {
        chomp ($line);    

        #File is of the format Name Chr Position

        $csv->parse($line);

        my ($bin,$chr, $start0, $pos, $snp_id, $score, $strand, $observed_alleles) = $csv->fields();

        next if($bin =~ /^\#bin/xi); #skip header
        $chr =~ s/^chr//;   #adjust from UCSC chromsome notation
        $chr =~ s/^M$/MT/; #further adjust chr

        if(exists($calls->{$snp_id})) {
            #Expecting forward strand calls
            #check that this is the case
            #
            #THIS DID NOT HELP, BUT THE LOGIC SEEMS LIKE IT MAY PROVE USEFUL AT A LATER DATA
            #
            #if(exists($probe->{$snp_id})) {
            #    #determine forward strand
            #    my ($name_il_strand, $name_dbSNP_strand) = $probe->{$snp_id}{id} =~ /\_(\D)\_(\D)\_/;
            #    if($name_dbSNP_strand eq 'R') {
            #        $alleles_altered = $name_il_strand eq $probe->{$snp_id}{strand} ? 1 : 0;
            #    }
            #    elsif($name_dbSNP_strand eq 'F') {
            #        $alleles_altered = $name_il_strand eq $probe->{$snp_id}{strand} ? 0 : 1;
            #    }
            #    else {
            #        $self->error_message("Parsing error. Unknown dbSNP strand");
            #        die;
            #    }

            #}
            #else {
            #    $self->error_message("Probe id $snp_id not found in Illumina probe file");
            #    die;
            #}



            ##Check alleles to make sure that what we're getting from Illumina matches what we get from UCSC
            #if($alleles_altered) {
            #    $observed_alleles =~ tr/ACTGactg/TGACtgac/;
            #}

            unless($self->contains_expected_alleles($observed_alleles, $calls->{$snp_id})) {
                #try reverse complementing
                map {$_ =~ tr/ACTGactg/TGACtgac/ } @{$calls->{$snp_id}};
                unless($self->contains_expected_alleles($observed_alleles, $calls->{$snp_id})) {            
                    my @alleles = @{$calls->{$snp_id}};                                
                    $self->error_message("Unexpected alleles for probe $snp_id. Expected $observed_alleles. Got @alleles");
                    next;
                }
            }
            if($strand eq '-' ) {
                #adjust stranding to +/- instead of forward/reverse
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

sub contains_expected_alleles {
    my ($self, $expected_alleles, $reported_calls_ref) = @_;

    my %expected_alleles = map { uc($_) => 1 } split /\//, $expected_alleles;
    my @reported_alleles = map { split // } @$reported_calls_ref;
    foreach my $allele (@reported_alleles) {
        unless(exists($expected_alleles{uc($allele)})) {
            return;
        }
    }
    return 1;
}


1;

sub help_brief {
    "Converts Affy genotype call file into actual base calls"
}

