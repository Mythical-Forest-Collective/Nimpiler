import compiler/[ast, modulegraphs, msgs]

import std/[streams, intsets, os, options]

type
  SerializeCtx = object
    ## Stores context information
    seenSyms, seenTypes: IntSet
    deferredSyms*: seq[PSym]
    deferredTypes*: seq[PType]

  Collected[T] = object
    data: seq[T]
    marker: IntSet

  SerialisedFlags = object

  SerialisedIdent = object
    s*:string  # Adding this in for future proofing

  SerialisedSymbol = object


  # Note: For now, we're only handling the minimal amount of data,
  # if we need to collect more, we can add it here
  SerialisedNode = object
    id*:int
    typ*:string
    flags*:SerialisedFlags

    # Reason why we have a separate field for simple kind is so it's simpler for the target language to
    # handle, though using the `kind` field would definitely be preferred if the language has a more
    # detailed way to represent the type
    simpleKind*: string

    case kind*: TNodeKind
    of nkCharLit .. nkUInt64Lit:
      intVal*: BiggestInt

    of nkFloatLit .. nkFloat128Lit:
      floatVal*: BiggestFloat

    of nkStrLit .. nkTripleStrLit:
      strVal*: string

    of nkSym:
      sym*: SerialisedSymbol

    of nkIdent:
      ident*: SerailisedIdent

    else:
      children*: seq[SerialisedNode]

  SerialisedModule = object
    path*:string
    top_level*:SerialisedNode

  SerialisedOutput = object  # TODO: Figure out a better name for this
    modules*:seq[SerialisedModule]

func collect(x: PSym, syms: var Collected[PSym], types: var Collected[PType]) =
  if syms.marker.containsOrIncl(x.id):
    return
  
  syms.data.add x

# use ``collect`` on all symbols and types that are directly referenced by `x`

# TODO: Implement `collect` for PNodes too

proc serialiseNode*(serialiseOutput: SerialisedOutput, ctx: var SerializeCtx, n: PNode) =
  if n == nil:
    return nil

  s.write "{"
  s.writeField "id", n.id
  
  s.write ","
  s.withKey "typ":
    s.serializeTypeRef(ctx, n.typ)

  field flags
  field kind
  case n.kind
  of nkCharLit..nkUInt64Lit:
    field intVal
  of nkFloatLit..nkFloat128Lit:
    field floatVal
  of nkStrLit..nkTripleStrLit:
    field strVal
  of nkSym:
    s.write ","
    s.withKey "sym":
      s.serializeSymRef(ctx, n.sym)
  of nkIdent:
    field ident
  else:
    s.write ","
    s.withKey "sons":
      if n.kind != nkEmpty:
        for son in serItemsIt(s, n.sons):
          s.serialize(ctx, son)

proc serialise(graph:ModuleGraph, mlist: ModuleList) =
  ## Serializes the `graph` and `mlist` to JSON and writes it to the stream `s`
  # TODO: serialization of the relevant `graph` parts is missing

  var ctx: SerializeCtx

  var serialisedOutput = SerialisedOutput(
    modules:newSeq[SerialisedModule]()
  )

  # serialize the top-level statements and declarations for each module 
  for m in mlist.modules.items:
    let
      nimfile = AbsoluteFile toFullPath(graph.config, m.sym.position.FileIndex)

    for n in m.nodes.items:
      serialize(serialisedOutput, ctx, n)

    serialisedOutput.modules.add(SerialisedModule(path:nimfile.string, top_level:"PLACEHOLDER"))