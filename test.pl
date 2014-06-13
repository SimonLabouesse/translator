#!/usr/bin/perl
use strict;
use warnings;
use Cwd;


my $exp = '$1';
my $truc = 1;
#my $regex = m/'\s*(\w+)\s+ \g1\s*'/;
my $text = "test test ok ok  ";

print("$text\n\n") ;
sub rep
{
	my ($input1,$input2,$input3,$input4,$testd) = @_;
	#print("$testd\n");
	#print("$input1\n") if( defined $input1);
	#print("$input2\n") if( defined $input2);
	my $string="";
	$string="ko" if($input1 eq "ok");
	$string="tset" if($input1 eq "test");	
	#return "ko" if(($input2 eq "ok") and ( defined $input2));
	#return "uocuoc" if(($input2 eq "test")and( defined $input2));
	$testd =~ s/$input1/$string/g;
	return $testd ;
	
}

$text =~ s/(\w+)\s+\g1/eval 'rep($1,$2,$3,$4,$&)'/eg;	

print("$text\n");





