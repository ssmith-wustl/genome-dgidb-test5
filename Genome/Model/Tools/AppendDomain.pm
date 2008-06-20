package Genome::Model::Tools::AppendDomain;

use strict;
use warnings;

# this probably need a bit more documentation

use above "Genome";
use Command;
use Carp;
use IO::File;
use File::Slurp;
use Text::CSV_XS;
use File::Temp qw/ tempfile /;
use List::MoreUtils qw/ uniq /;

UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'maf' => { type => 'String',
                                            doc => "mutation annotation file",
                                            required => 1},
                                 'filter' => { type => 'String',
                                               doc => "filter expression for domains",
                                               },
                                 'output' => { type => 'String',
                                               doc => "output file name",
                                               required => 1},
                                 'gcol' => { type => 'Integer',
                                             doc => "hugo gene name column",
                                             default => 0},
                                 'tcol' => { type => 'Integer',
                                             doc => "transcript name column",
                                             default => 3},
                                 'acol' => { type => 'Integer',
                                             doc => "Amino acid change column",
                                             default => 12},
                                 'sepchar' => { type => 'String', 
                                                doc => "separator character in matrix", 
                                                is_optional => 1,
                                                default => "\t"},
]
                         );

sub help_brief
{
    "tool for appending interproscan domain results to mutation annotation file";
}


sub execute
{
    my $self = shift;
    # preprocess a temp file for the 'snp file'.

    my $tmpfile = $self->extract_snp_data2tmpfile();

    # do SnpDom stuff.
    my $snpdomains = new SnpDom( '-inc-ts' => 1, );
    my $muthash;
    my %pfamlen;
    my $mutcounts;

    # read in mutations
    $snpdomains->read_muts( $tmpfile, "1,2" );
    $muthash = $snpdomains->get_all_mutations();
    $snpdomains->mutation_in_dom( \%pfamlen, $self->filter );
    $mutcounts = $snpdomains->get_mutation_counts();

    my @mutrecs = read_file($self->maf) or croak "can't read " .$self->maf ." : $!";
    chomp(@mutrecs);

    my $c = new Text::CSV_XS( { sep_char => $self->sepchar } );
    my %hash;
    # start appending to the records.
    foreach my $line (@mutrecs)
    {
        $c->parse($line);
        my @f        = $c->fields();
        my $gene     = $f[$self->gcol];
        my $tname    = $f[$self->tcol];
        my $aachange = $f[$self->acol];
        push( @{ $hash{$gene}{$tname} }, $aachange );
    }

    my @new;
    
    foreach my $l (@mutrecs)
    {
        $c->parse($l);
        my @f        = $c->fields();
        my $gene     = $f[$self->gcol];
        my $tname    = $f[$self->tcol];
        my $aachange = $f[$self->acol];
        my $obj      = $snpdomains->get_mut_obj( $tname . "," . $gene );
        if ( defined($obj) )
        {
            my $doms = $obj->get_domain($aachange);
            if ( defined($doms) )
            {
                $f[ $#f + 1 ] = join( ":", uniq @$doms );
            }
        }
        $c->combine(@f);
        push( @new, $c->string() . "\n" );
    }
    
    write_file( $self->output, @new );

    return 1;
}

sub extract_snp_data2tmpfile
{
    my $self = shift;
    my ($fh,$tmpfile) = tempfile("gt-append-domainXXXXXX", SUFFIX => '.dat');
    my $c = new Text::CSV_XS({sep_char => $self->sepchar});
    my @lines = read_file($self->maf);
    my @tmp;
    foreach my $l (@lines)
    {
        $c->parse($l);
        my @f = $c->fields();

        my $nr = $f[$self->gcol] . "\t" . 
                 $f[$self->tcol] . "," . $f[$self->gcol] . "\t" .
                 $f[$self->acol] . "\n";
        push(@tmp, $nr);
    }
    write_file($tmpfile,@tmp);
    return $tmpfile;
}
