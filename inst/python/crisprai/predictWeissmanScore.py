import cPickle
from sgRNA_learning_pamfix import *


def predictWeissmanScore(tssTable, p1p2Table, sgrnaTable, libraryTable, pickleFile, fastaFile, chromatinFiles, modality, verbose):
   
    # open pickle file to continue from previously trained session/model
    try:
        with open(pickleFile) as infile:
            fitTable, estimators, scaler, reg, transformedParams_train_header = cPickle.load(infile)
    except:
        raise Exception('Trained model file not found.') 

    # set indices for pd dataframes
    tssTable = tssTable.set_index(['gene', 'transcripts'])
    p1p2Table = p1p2Table.set_index(['gene', 'transcript'])
    sgrnaTable = sgrnaTable.set_index('sgId')
    libraryTable = libraryTable.set_index('sgId')

    paramTable = getParamTable(tssTable, p1p2Table, sgrnaTable, libraryTable, fastaFile, chromatinFiles, verbose = verbose)
    
    transformedParams_new = getTransformedParams(paramTable, fitTable, estimators, verbose = verbose)

    print 'Predicting sgRNA scores...'
    try:
        predictedScores = pd.Series(reg.predict(scaler.transform(transformedParams_new.loc[:, transformedParams_train_header.columns].fillna(0).values)), index=transformedParams_new.index)
    except:
        raise Exception("Error getting predictions. Environment may be corrupted. Please try reinstalling package.")

    return predictedScores

def getParamTable(tssTable, p1p2Table, sgrnaTable, libraryTable, fastaFile, chromatinFiles, verbose):
    
    try:
        genomeDict=loadGenomeAsDict(fastaFile)
    except:
        raise Exception("Genome FASTA file not found. Error in file or file does not exist.")

    if verbose == True:
        print "Loading chromatin data..."

    try:
        bwhandleDict = {'dnase':BigWigFile(open(chromatinFiles[0])), 'faire':BigWigFile(open(chromatinFiles[1])), 'mnase':BigWigFile(open(chromatinFiles[2]))}
    except:
        raise Exception("Could not load chromatin data. Error in files or files do not exist.")

    # parse primary TSS and secondary TSS
    p1p2Table['primary TSS'] = p1p2Table['primary TSS'].apply(lambda tupString: (int(tupString.strip('()').split(', ')[0].split('.')[0]), int(tupString.strip('()').split(', ')[1].split('.')[0])))
    p1p2Table['secondary TSS'] = p1p2Table['secondary TSS'].apply(lambda tupString: (int(tupString.strip('()').split(', ')[0].split('.')[0]),int(tupString.strip('()').split(', ')[1].split('.')[0])))

    if verbose == True:
        print "Calculating parameters..."

    try:
       paramTable = generateTypicalParamTable(libraryTable, sgrnaTable, tssTable, p1p2Table, genomeDict, bwhandleDict)
    except:
       raise Exception("Error generating parameter table.")
     
    return paramTable


def getTransformedParams(paramTable, fitTable, estimators, verbose):
    
    if verbose == True:
        print 'Transforming parameters...'

    try:
        transformedParams_new = transformParams(paramTable, fitTable, estimators)
    except:
        raise Exception("Error transforming parameters.")

    # reconcile differences in column headers
    colTups = []
    for (l1, l2), col in transformedParams_new.iteritems():
        colTups.append((l1,str(l2)))
    transformedParams_new.columns = pd.MultiIndex.from_tuples(colTups)

    return transformedParams_new