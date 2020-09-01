#! /bin/bash


#SBATCH -o "results-%j.txt" # ceci permet d'enregistrer directement le sbatch dans un fichier texte
#SBATCH --cpus-per-task=8
#SBATCH	--ntasks=1


######## DATA ##############

#on va dans le dossier d'intérêt
cd ~/ProjetM5 
#création du dossier Data 
mkdir "Data"
#on va dans le dossier data pour enregistrer les données dedans
cd ~/ProjetM5/Data
#wget permet de télécharger les données à partir de l'URL donné 
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/009/045/GCF_000009045.1_ASM904v1/GCF_000009045.1_ASM904v1_genomic.gff.gz 
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/009/045/GCF_000009045.1_ASM904v1/GCF_000009045.1_ASM904v1_genomic.fna.gz


 # je dézippe les données obtenus 

gzip -d GCF_000009045.1_ASM904v1_genomic.fna.gz
gzip -d GCF_000009045.1_ASM904v1_genomic.gff.gz


# je vais chercher l'outil sra tools 
module load sra-tools

# la commande fasterq-dump permet de récupérer les fichiers fastq associé au numéro SRA: SRR10390685
# -S pour que chaque run soit dans un fichier 
# cpus limités à 8 
srun --cpus-per-task=8 fasterq-dump -S SRR10390685 --outdir . --threads 8
gzip SRR10390685_1.fastq
gzip SRR10390685_2.fastq 


######## FastQC ##############

module load fastqc
cd ~/ProjetM5 
mkdir "FastQC"

cd ~/ProjetM5/FastQC

srun --cpus-per-task=8 fastqc ~/ProjetM5/Data/SRR10390685_1.fastq.gz -o . -t 8
srun --cpus-per-task=8 fastqc ~/ProjetM5/Data/SRR10390685_2.fastq.gz -o . -t 8

module load fastp
srun --cpus-per-task=8 fastp --in1 ~/ProjetM5/Data/SRR10390685_1.fastq.gz --in2 ~/ProjetM5/Data/SRR10390685_2.fastq.gz -l 100 --out1 ~/ProjetM5/Data/SRR10390685_1.paired.fastq.gz --out2 ~/ProjetM5/Data/SRR10390685_2.paired.fastq.gz --unpaired1 ~/ProjetM5/Data/SRR10390685_unpaired.fastq.gz --unpaired2 ~/ProjetM5/Data/SRR10390685_unpaired.fastq.gz -w 1 -h Reportfastp.html -t 8

cd ~/ProjetM5/


######## Indexing and Mapping  ##############

module load samtools
module load bwa


mkdir "Mapping"


 
cd ~/ProjetM5/Mapping

#Indexation du fichier fasta
module load samtools
samtools faidx GCF_000009045.1_ASM904v1_genomic.fna 
more GCF_000009045.1_ASM904v1_genomic.fna.fai 


srun bwa index ~/ProjetM5/Data/GCF_000009045.1_ASM904v1_genomic.fna

#Mapping avec l'outil BWA pour le samtools view -h permet de mettre un header au fichier et -b pour une sortie en bam.
srun --cpus-per-task=4 bwa mem ~/ProjetM5/Data/GCF_000009045.1_ASM904v1_genomic.fna ~/ProjetM5/Data/SRR10390685_1.paired.fastq.gz ~/ProjetM5/Data/SRR10390685_2.paired.fastq.gz -t 3 | samtools view -hb > MappingBWA_SRR10390685.bam
#Statistiques du mapping 
samtools flagstat MappingBWA_SRR10390685.bam 
#Tri du fichier bam
samtools sort MappingBWA_SRR10390685.bam -o MappingBWA_SRR10390685_sorted.bam

#Je cherche toutes les lignes ayant le mot "trmNF"
grep trmNF ~/ProjetM5/Data/GCF_000009045.1_ASM904v1_genomic.gff > ~/ProjetM5/Data/Gene_trmNF.gff
#je récupère toutes les lignes dont la colonne contient "gene"
awk '$3=="gene"' > ~/ProjetM5/Data/Gene_trmNF.gff

module load bedtools


cd ~/ProjetM5/Mapping
#On indexe le fichier bam trié pour intersect
srun samtools index MappingBWA_SRR10390685_sorted.bam 
#intersect permet de connaitre les reads qui couvre au moins 50% du gène -a cible 1 et on met notre fichier bam, -b cible 2 le gène ciblé et -f à 0,5 permet de voir les reads (a) qui chevauchent à 50% le gene (b)
bedtools intersect -a MappingBWA_SRR10390685_sorted.bam -b ~/ProjetM5/Data/Gene_trmNF.gff -f 0.5 > Mapping_inter50_trmNF.bam
#Visualisation du bam
samtools view -c Mapping_inter50_trmNF.bam


