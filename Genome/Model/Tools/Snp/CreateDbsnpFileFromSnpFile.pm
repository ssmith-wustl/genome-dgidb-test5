package Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile;

use strict;
use warnings;

use Genome;
use Genome::DB::Schema;
use Command;
use IO::File;
#use Genome::DB::Schema;

class Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile {
    is => 'Command',
    has => [
    snp_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "Input file of maq cns2snp output for a single individual",
    },
    output_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Output file name for dbSNP-127/Watson/Venter intersect file",
    },        
    ],
};


sub execute {
    my $self=shift;
    $DB::single=1; 
    # local $| = 1;
    

    unless(-f $self->snp_file) {
        $self->error_message("Snp file is not a file: " . $self->snp_file);
        return;
    }

    my $snp_fh = IO::File->new($self->snp_file);
    unless($snp_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->snp_file );
        return;
    }

    my $output_fh = IO::File->new($self->output_file, "w");
    unless($output_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->output_file );
        return;
    }

    #print output header
    print $output_fh "chromosome\tstart\tend\tdbSNP-127\tWATSON\tVENTER\n";

#    my $snps_at = $self->make_snp_file_hash($snp_fh);
#    $snp_fh->close;

    #make db connection
    my $schema = Genome::DB::Schema->connect_to_dwrac;
    $self->error_message("Can't connect to dwrac") and return unless $schema;

    ##########3
    ############
    #If iterating through Variation
    #my $rs = $schema->resultset('Variation');
    #while ( my $var = $rs->next ) { 
    #}
    #assuming we are reasonably sorted
    my $chrom; #= #$schema->resultset('Chromosome')->find({ name => '1' });
    my $var_window;# = $chrom->variation_window;
    
    while ( my $line = $snp_fh->getline) {
        #    print STDERR "\r",$snp_fh->input_line_number;
        chomp $line;
        my %snp;
        @snp{('chrom','position')} = split /\s+/, $line; 
        if (!defined($chrom) || $snp{chrom} ne $chrom->chromosome_name ) {
            #get new var window;
            $chrom = $schema->resultset('Chromosome')->find({ chromosome_name => $snp{chrom}});
            if(defined($chrom)) {
                $var_window = $chrom->variation_window;
            }
            else {
                next;
            }
        }

        my %submitters;
        for my $var ( grep { $_->start_ == $snp{position} && $_->start_ == $_->end } $var_window->scroll( $snp{position} ) ) {
            next if $var->allele_string =~ m#\-#;
            @submitters{ map { $_->variation_source } $var->submitters } = 1; 
        }

        my $dbsnp_string = join "\t", (map {$_ ||= 0} @submitters{('dbSNP-127','WATSON','VENTER')});

        #only print SNPs that are in dbSNP, Watson or Venter
        if($dbsnp_string ne "0\t0\t0") { 
            printf $output_fh "%s\t%d\t%d\t$dbsnp_string\n",$snp{chrom},$snp{position},$snp{position};
        }
    }



    ###########33
    #############
    
    #grab DBIx class Eddie made
    #my $counter = 0;
    #my $page = 1;
    #my $variations = $schema->resultset('Variation')->search(undef, { rows => 10000, order_by => 'start_'});
    #while(my $variation_itr = $variations->page($page++)) {
    #    while(my $variation = $variation_itr->next) {
    #        #        print "\r",++$counter;
    #        next if($variation->allele_string =~ /-/); #ignore deletions 
    #        my $start = $variation->start_;
    #        next if($start != $variation->end);
    #        my $chr = $variation->chromosome->chromosome_name;
    #        $chr = $chr =~ /^\d+/ ? sprintf("%02d",$chr) : $chr;
    #        next if(!exists($snps_at->{$chr}{$start}));
    #        my %submitters = map {$_->variation_source => 1} $variation->submitters;
    #        my $dbsnp_string = join "", (map {$_ ||= 0} @submitters{('dbSNP-127','WATSON','VENTER')});
    #        $snps_at->{$chr}{$start} = sprintf("%03d",$snps_at->{$chr}{$start} | $dbsnp_string); 
    #    }
    #}

    #my $output_fh = IO::File->new($self->output_file, "w");
    #unless($output_fh) {
    #    $self->error_message("Failed to open filehandle for: " .  $self->output_file );
    #    return;
    #}

    #$self->print_dbsnp_file($output_fh,$snps_at);
    $snp_fh->close; 
    $output_fh->close;
    
    return 1;
}

1;

sub help_detail {
    return "This module takes a snp list and creates a file of its intersections with dbSNP-127, Watson, and Venter genomes";
}

sub help_brief {
    return "Create a dbSNP/Watson/Venter file";
}

sub make_snp_file_hash {
    my ($self,$handle) = @_;
    my %snp_at;
    while(my $line = $handle->getline) {
        chomp $line;
        my ($chr, $start,) = split /\s+/, $line;
        #use Brian's trick of padding the chromosome
        $chr = $chr =~ /^\d+/ ? sprintf("%02d",$chr) : $chr;
        $snp_at{$chr}{$start} = '000';
    }
    return \%snp_at;

}

sub print_dbsnp_file {
    my ($self,$handle,$snps) = @_;
    print $handle "chromosome\tstart\tend\tdbSNP-127\tWATSON\tVENTER\n";
    foreach my $chr (sort (keys %{$snps})) {
        my $chromosome = $chr;
        $chromosome =~ s/^0//;
        foreach my $pos (sort { $a <=> $b } (keys %{$snps->{$chr}})) {
            my $dbsnp_string = join "\t", split //, $snps->{$chr}{$pos}; 
            print $handle "$chromosome\t$pos\t$pos\t$dbsnp_string\n";
        }
    }
}
