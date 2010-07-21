#!/gsc/bin/perl

use strict;
use warnings;
use above "Genome";
use IPC::Run;
use Test::More tests => 7;


use_ok('Genome::Model::Tools::Annotate::AminoAcidSubstitution');
my $test_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-AminoAcidSubstitution";
ok (-d $test_dir);
my $expected = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-AminoAcidSubstitution/expected.txt";
ok (-e $expected);

my $output = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Annotate-AminoAcidSubstitution/output";
my @command = ["rm" , "$output.txt"];
&ipc_run(@command);

my $AminoAcidSubstitution = Genome::Model::Tools::Annotate::AminoAcidSubstitution->create(transcript => "ENST00000269305", amino_acid_substitution => "S166C", organism => "human", version => "54_36p_v2", output => $output);
ok ($AminoAcidSubstitution);
my ($amino_acid_substitution) = $AminoAcidSubstitution->execute();
ok ($amino_acid_substitution);
ok (-e "$output.txt");

@command = ["diff" , $expected , "$output.txt"];
my ($out) = &ipc_run(@command);
ok (! $out);

sub ipc_run {
    
    my (@command) = @_;
    my ($in, $out, $err);
    IPC::Run::run(@command, \$in, \$out, \$err);
    
    return unless $out;
    return $out;	    
    
}
