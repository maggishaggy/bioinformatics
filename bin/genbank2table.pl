#!/usr/bin/perl -w

# get proteins out of a genbank file

use Bio::SeqIO;
use strict;

my $usage=<<EOF;
$0 [-v (for verbose output)] [-d DNA file for genes] [-g DNA file for genome] [-p proteins file] [-f functions file] <list of genbankfiles>

EOF

die $usage unless ($ARGV[0]);

my @infiles;
my $verbose=0;

my $dnaF;
my $protF;
my $funcF;
my $genomeF;

while (@ARGV) {
	my $f = shift @ARGV;
	if ($f eq "-d") {$dnaF = shift @ARGV}
	elsif ($f eq "-p") {$protF = shift @ARGV}
	elsif ($f eq "-f") {$funcF = shift @ARGV}
	elsif ($f eq "-g") {$genomeF = shift @ARGV}
	elsif ($f eq "-v") {$verbose = 1}
	else {push @infiles, $f}
}

unless ($protF || $funcF || $genomeF || $dnaF) {die "Please specify one of -f, -g, -p, -d.\n$usage\n"}

if ($protF && -e $protF) {die "$protF already exists. Not overwriting\n"}
if ($funcF && -e $funcF) {die "$funcF already exists. Not overwriting\n"}
if ($dnaF && -e $dnaF) {die "$dnaF already exists. Not overwriting\n"}
if ($genomeF && -e $genomeF) {die "$genomeF already exists. Not overwriting\n"}

if (defined $protF) {open(FA, ">$protF") || die "Can't open fasta $protF"}
if (defined $funcF) {open(PR, ">$funcF") || die "Can't open function $funcF"}
if (defined $dnaF) {open(SQ, ">$dnaF") || die "can't open sequences $dnaF"}
if (defined $genomeF) {open(GF, ">$genomeF") || die "can't open sequences $genomeF"}

my $seedid=&seedid;
if ($seedid) {open(CO, ">contigs") || die "Can't open contigs"}

my $c;
foreach my $file (@infiles)
{
	my $sio=Bio::SeqIO->new(-file=>$file, -format=>'genbank');
	while (my $seq=$sio->next_seq) {
		if (defined $genomeF) {print GF ">", $seq->display_name, "\n", $seq->seq, "\n"}
		my $seqname=$seq->display_name;
		my $source = "";
		#my $source = $seq->source;
		if ($verbose) {print STDERR "Parsing $seqname\n"}
		if ($seedid->{$seqname}) {print CO join("\t", $seedid->{$seqname}, $seqname)}
		my $organism; my $taxid;

		foreach my $feature ($seq->top_SeqFeatures()) {
			#my $ftype;
			#eval {$ftype=$feature->primary()};

			#next unless ($ftype eq "CDS");
			if ($feature->has_tag('organism')) {
				$organism = join(" ", $feature->each_tag_value('organism'));
				my $dbx = join(" ", $feature->each_tag_value('db_xref'));
				$dbx =~ m/taxon:(\d+)/;
				$taxid = $1;
			}

			$c++;
			my $id; # what we will call the sequence
			my ($trans, $gi, $geneid, $prod, $locus, $np);

			eval {$trans = join " ", $feature->each_tag_value("translation")};
			eval {$np = join " ", $feature->each_tag_value("protein_id")};
			if (!$np) {
				my $fig = "";
				eval {$fig = join(" ", $feature->each_tag_value("db_xref"))};
				if ($fig) {
					$fig =~ m/SEED\:(fig\|\d+\.\d+\....\.\d+)/;
					$np = $1;
				}
			}
			if ($trans && !$np) {
				if ($verbose) {print STDERR "No NP for $trans. Skipped\n"}
				next;
			}
			elsif (!$trans && $np) {
				if ($verbose) {print STDERR "No translation for $np. Skipped\n"}
				next;
			}
			next unless ($trans && $np);

			eval {
				foreach my $xr ($feature->each_tag_value("db_xref")) 
				{
					($xr =~ /GI/) ? ($gi = $xr) : 1;
					($xr =~ /GeneID/) ? ($geneid = $xr) : 1;
				}
			};

			eval {$locus = join " ", $feature->each_tag_value("locus_tag")};
			eval {$prod  = join " ", $feature->each_tag_value("product")};

			my $end = $feature->end;
			my $start = $feature->start;

			my $oids="";
			($locus)   && ($oids.="locus:$locus;");
			($geneid)  && ($oids.="$geneid;");
			($gi)      && ($oids.="$gi;");
			$oids =~ s/\;$//;

			unless ($prod)  {
				if ($verbose) {print STDERR "No product for $np\n"}
				$prod="hypothetical protein";
			}
			if (defined $dnaF) {print SQ ">$np\n", $feature->seq()->seq(), "\n"}
			if (defined $protF) {print FA ">$np\n$trans\n"}
			if (defined $funcF) {print PR "$np\t$start\t$end\t$prod\t$oids\t$seqname\t$organism\t$taxid\t", $seq->display_name, "\n"}
		}
	}
}


sub seedid {
	return unless (-e "../NCs.txt");
	open(IN, "../NCs.txt");
	my %seedid;
	while (<IN>) 
	{
		chomp;
		my ($id, $name, @acc)=split /\t/;
		map {$seedid{$_}=$id} @acc;
	}
	return \%seedid;
}

