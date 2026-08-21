local M = {}

local LANGAGE = "c_sharp"

local function client_roslyn(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr, name = "roslyn" })[1]
end

local function buffer_charge_pour(fichier)
  local bufnr = vim.fn.bufadd(fichier)
  vim.fn.bufload(bufnr)
  return bufnr
end

local function racine_syntaxique(bufnr)
  local ok, parseur = pcall(vim.treesitter.get_parser, bufnr, LANGAGE)
  if not ok or not parseur then return nil end
  return parseur:parse()[1]:root()
end

local function remonte_jusqu_a(noeud, types)
  while noeud do
    if types[noeud:type()] then return noeud end
    noeud = noeud:parent()
  end
  return nil
end

local NOMS_QUALIFIES = {
  member_access_expression = true,
  qualified_name = true,
  generic_name = true,
  conditional_access_expression = true,
  member_binding_expression = true,
}

local function expression_designant_la_methode(identifiant)
  local expression = identifiant
  while expression:parent() and NOMS_QUALIFIES[expression:parent():type()] do
    expression = expression:parent()
  end
  return expression
end

local function liste_a_completer(bufnr, ligne, colonne)
  local identifiant = vim.treesitter.get_node({ bufnr = bufnr, pos = { ligne, colonne } })
  if not identifiant then return nil, "position hors de l'arbre syntaxique" end

  local declaration = remonte_jusqu_a(identifiant, { method_declaration = true, local_function_statement = true })
  if declaration and declaration:field("name")[1] == identifiant then
    return { noeud = declaration:field("parameters")[1], nature = "déclaration" }
  end

  local expression = expression_designant_la_methode(identifiant)
  local appel = expression:parent()
  if appel and appel:type() == "invocation_expression" and appel:field("function")[1] == expression then
    return { noeud = appel:field("arguments")[1], nature = "appel" }
  end

  return nil, "ni déclaration ni appel (groupe de méthodes, documentation ou usage indirect)"
end

local function contient_un_argument_nomme(bufnr, liste)
  for enfant in liste:iter_children() do
    if enfant:named() and enfant:type() == "argument" then
      local texte = vim.treesitter.get_node_text(enfant, bufnr)
      if texte:match("^%s*[%a_][%w_]*%s*:") and not texte:match("^%s*[%a_][%w_]*%s*::") then
        return true
      end
    end
  end
  return false
end

local function insertion_avant_la_parenthese_fermante(bufnr, liste, texte_a_inserer)
  local _, _, ligne_fin, colonne_fin = liste:range()
  local separateur = liste:named_child_count() > 0 and ", " or ""
  return {
    bufnr = bufnr,
    ligne = ligne_fin,
    colonne = colonne_fin - 1,
    texte = separateur .. texte_a_inserer,
  }
end

local function position_du_noeud(noeud)
  local ligne, colonne = noeud:range()
  return { line = ligne, character = colonne }
end

local function dernier_identifiant(expression)
  if expression:type() == "identifier" then return expression end
  for enfant in expression:iter_children() do
    if enfant:type() == "identifier" then expression = enfant end
  end
  return expression
end

local function methode_visee_par_le_curseur(bufnr, ligne, colonne)
  local noeud = vim.treesitter.get_node({ bufnr = bufnr, pos = { ligne, colonne } })
  if not noeud then return nil, "position hors de l'arbre syntaxique" end

  local declaration = remonte_jusqu_a(noeud, { method_declaration = true, local_function_statement = true })
  if declaration then
    local nom = declaration:field("name")[1]
    local parametres = declaration:field("parameters")[1]
    local curseur_sur_la_signature = noeud == nom
      or (parametres and vim.treesitter.is_in_node_range(parametres, ligne, colonne))
    if curseur_sur_la_signature then
      return position_du_noeud(nom), vim.treesitter.get_node_text(nom, bufnr)
    end
  end

  local expression = expression_designant_la_methode(noeud)
  local appel = expression:parent()
  if appel and appel:type() == "invocation_expression" and appel:field("function")[1] == expression then
    local nom = dernier_identifiant(expression)
    return position_du_noeud(nom), vim.treesitter.get_node_text(nom, bufnr)
  end

  return nil, string.format(
    "Place le curseur sur le nom de la méthode ou dans sa liste de paramètres (ici : %s « %s »).",
    noeud:type(), vim.treesitter.get_node_text(noeud, bufnr):sub(1, 30))
end

local function references_de_la_methode(client, bufnr, position, suite)
  client:request("textDocument/references", {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = position,
    context = { includeDeclaration = true },
  }, function(err, references)
    if err then
      return vim.notify("Roslyn n'a pas répondu : " .. vim.inspect(err), vim.log.levels.ERROR)
    end
    suite(references or {})
  end, bufnr)
end

local function classer_les_references(references, parametre, argument)
  local modifications, ignorees = {}, {}

  for _, reference in ipairs(references) do
    local fichier = vim.uri_to_fname(reference.uri)
    local bufnr = buffer_charge_pour(fichier)
    local ligne = reference.range.start.line
    local colonne = reference.range.start.character

    if not racine_syntaxique(bufnr) then
      table.insert(ignorees, { fichier = fichier, ligne = ligne + 1, raison = "parser C# indisponible" })
    else
      local cible, raison = liste_a_completer(bufnr, ligne, colonne)
      if not cible then
        table.insert(ignorees, { fichier = fichier, ligne = ligne + 1, raison = raison })
      elseif cible.nature == "appel" and argument == "" then
        table.insert(ignorees, { fichier = fichier, ligne = ligne + 1, raison = "aucun argument demandé" })
      elseif cible.nature == "appel" and contient_un_argument_nomme(bufnr, cible.noeud) then
        table.insert(ignorees, { fichier = fichier, ligne = ligne + 1, raison = "arguments nommés : ordre à vérifier à la main" })
      else
        local texte = cible.nature == "déclaration" and parametre or argument
        table.insert(modifications, insertion_avant_la_parenthese_fermante(bufnr, cible.noeud, texte))
      end
    end
  end

  return modifications, ignorees
end

local function du_bas_vers_le_haut(a, b)
  if a.bufnr ~= b.bufnr then return a.bufnr < b.bufnr end
  if a.ligne ~= b.ligne then return a.ligne > b.ligne end
  return a.colonne > b.colonne
end

local function appliquer(modifications)
  table.sort(modifications, du_bas_vers_le_haut)
  local buffers = {}
  for _, m in ipairs(modifications) do
    vim.api.nvim_buf_set_text(m.bufnr, m.ligne, m.colonne, m.ligne, m.colonne, { m.texte })
    buffers[m.bufnr] = true
  end
  return vim.tbl_keys(buffers)
end

local function resume(modifications, ignorees)
  local par_fichier = {}
  for _, m in ipairs(modifications) do
    local nom = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(m.bufnr), ":t")
    par_fichier[nom] = (par_fichier[nom] or 0) + 1
  end
  local lignes = {}
  for nom, n in pairs(par_fichier) do
    table.insert(lignes, string.format("  %s : %d", nom, n))
  end
  table.sort(lignes)
  table.insert(lignes, 1, string.format("%d insertion(s) dans %d fichier(s) :", #modifications, vim.tbl_count(par_fichier)))
  if #ignorees > 0 then
    table.insert(lignes, string.format("%d référence(s) ignorée(s) :", #ignorees))
    for _, i in ipairs(ignorees) do
      table.insert(lignes, string.format("  %s:%d — %s", vim.fn.fnamemodify(i.fichier, ":t"), i.ligne, i.raison))
    end
  end
  return table.concat(lignes, "\n")
end

function M.ajouter_un_parametre()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = client_roslyn(bufnr)
  if not client then
    return vim.notify("Aucun serveur Roslyn attaché à ce buffer.", vim.log.levels.ERROR)
  end
  if not M.solution_prete(client) then
    return vim.notify("Solution en cours d'indexation : les appels ne seraient pas tous trouvés.", vim.log.levels.WARN)
  end

  local curseur = vim.api.nvim_win_get_cursor(0)
  local position, methode = methode_visee_par_le_curseur(bufnr, curseur[1] - 1, curseur[2])
  if not position then
    return vim.notify(methode, vim.log.levels.WARN, { title = "Ajouter un paramètre" })
  end

  local parametre = vim.fn.input(string.format("Paramètre à ajouter à %s (ex. bool isActif) : ", methode))
  if parametre == "" then return end
  local argument = vim.fn.input("Argument à passer aux appels (vide = ne pas les toucher) : ")

  references_de_la_methode(client, bufnr, position, function(references)
    if #references == 0 then
      return vim.notify("Aucune référence trouvée sous le curseur.", vim.log.levels.WARN)
    end

    local modifications, ignorees = classer_les_references(references, parametre, argument)
    if #modifications == 0 then
      return vim.notify("Rien à modifier.\n" .. resume(modifications, ignorees), vim.log.levels.WARN)
    end

    vim.ui.select({ "Appliquer", "Annuler" }, {
      prompt = resume(modifications, ignorees),
    }, function(choix)
      if choix ~= "Appliquer" then return end
      local buffers = appliquer(modifications)
      vim.notify(string.format("%d insertion(s) appliquée(s) dans %d buffer(s). Vérifie puis :wa",
        #modifications, #buffers), vim.log.levels.INFO)
    end)
  end)
end

M.solution_prete = function() return true end

function M.declarer_la_solution_prete(verificateur)
  M.solution_prete = verificateur
end

return M
