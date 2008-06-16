package Genome::Utility::VariantReviewListReader;

use strict;
use warnings;

use IO::File;

sub new{
    my ($class, $list, $separation_character) = @_;
    $separation_character ||= '|';
    my $lfh = IO::File->new("< $list");
    die "Can't open filehandle for $list!" unless $lfh;
    my $self = bless({lfh=>$lfh, separation_character=>$separation_character}, $class);
    return $self;
}

sub list_columns{
    my ($self, $column_name) = @_;;
    my @columns =( q/
        chromosome
        begin_position
        end_position
        variant_type
        variant_length
        delete_sequence
        insert_sequence
        genes
        supporting_samples
        supporting_dbs
        finisher_manual_review
        pass_manual_review
        finisher_3730_review
        manual_genotype_normal
        manual_genotype_tumor
        manual_genotype_relapse
        somatic_status
        notes
        /
    );
    return @columns unless $column_name;
    my $counter=0;
    while ($columns[$counter] ne $column_name){
        $counter++;
    }
    return $counter;
}

sub db_columns{
    my @columns =( q/
        chromosome
        begin_position
        end_position
        variant_type
        variant_length
        delete_sequence
        insert_sequence
        insert_sequence_allele1
        insert_sequence_allele2
        genes
        supporting_samples
        supporting_dbs
        finisher_manual_review
        pass_manual_review
        finisher_3730_review
        manual_genotype_normal
        manual_genotype_tumor
        manual_genotype_relapse
        somatic_status
        notes
        rgg_id
        roi_seq_id 
        sample_name
        variant_seq_id
        /
    );
    return @columns;
}

sub set_line_hash{
    my ($self, @data) = @_;
    my $index = 0;
    my %hash={};
    foreach my $col_name ($self->list_columns){
        if ($col_name eq 'insert_sequence'){
            my ($insert_sequence_allele1, $insert_sequence_allele2) ;
            ($insert_sequence_allele1, $insert_sequence_allele2) = split (/\//, $data[$index]) if $data[$index];
            $hash{'insert_sequence_allele1'} = $insert_sequence_allele1;
            $hash{'insert_sequence_allele2'} = $insert_sequence_allele2;
        }else{
            $hash{$col_name} = $data[$index];
        }
        $index++;
    }
    $self->{hash} = \%hash;
}

sub line_hash{
    my ($self)=@_;
    unless ($self->{hash}){
        die "no current line data present!";
    }
    return $self->{hash};
}

sub next_line_data{
    my ($self) = @_;
    my $line = $self->{lfh}->getline;
    chomp $line;
    if ($line =~ /^[\dXxYy]/){
        return {header=>$line};
    }
    my $char = $self->{'separation_character'};
    my @data = split(/\Q$char\E/, $line);
    foreach (@data){
        $_ =~ s/"'//g;
    }

    $self->set_line_hash(@data);
    return $self->line_hash;
}

1;


