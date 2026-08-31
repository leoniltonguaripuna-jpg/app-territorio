import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeuAplicativoCongregacao());
}

class MeuAplicativoCongregacao extends StatelessWidget {
  const MeuAplicativoCongregacao({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Território de Congregação',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFFA8B2A1),
      ),
      home: const TelaPrincipal(),
    );
  }
}

// MODELO DE DADOS PARA ADMINISTRADOR
class AdminModel {
  String nome;
  String pin;

  AdminModel({required this.nome, required this.pin});
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _abaSelecionada = 0;
  int? _territorioSelecionado;

  // CONTROLE DE ADMINS
  bool _eAdmin = false;
  String? _adminLogado;

  // Lista local de administradores
  final List<AdminModel> _listaAdmins = [
    AdminModel(nome: 'Administrador Principal', pin: '1234'),
  ];

  Uint8List? _bytesImagemTerritorio;

  // CONTROLADORES ABA 0 (TERRITÓRIOS)
  final TextEditingController _controllerLocal = TextEditingController(text: 'ELDORADO 1');
  final TextEditingController _controllerTerritorioNum = TextEditingController();

  final List<List<TextEditingController>> _controladoresRegistros = List.generate(
    8,
    (_) => List.generate(7, (_) => TextEditingController()),
  );

  final List<List<int>> _estadoQuadras = List.generate(
    8,
    (_) => List.generate(14, (_) => 0),
  );

  // CONTROLADORES ABA 3 (DIRIGENTES - 15 linhas x 3 colunas)
  final List<List<TextEditingController>> _controladoresDirigentes = List.generate(
    15,
    (_) => List.generate(3, (_) => TextEditingController()),
  );

  // ESTADO ABA 1 (SERVIÇO DE CAMPO)
  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;

  final Map<int, String> _locaisPadraoPorDiaDaSemana = {};
  final Map<int, List<List<TextEditingController>>> _cacheServicoCampo = {};

  final List<String> _nomesMeses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  final List<String> _diasDaSemanaTexto = [
    'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'
  ];

  // ESTRUTURA ABA 2 (EVENTOS - 14 linhas x 4 blocos)
  final List<List<TextEditingController>> _controladoresNomesEventos = List.generate(
    14,
    (_) => List.generate(4, (_) => TextEditingController()),
  );

  final List<List<Set<String>>> _diasSelecionadosEventos = List.generate(
    14,
    (_) => List.generate(4, (_) => <String>{}),
  );

  @override
  void initState() {
    super.initState();
    _carregarOuGerarMesAtual();
  }

  // DIÁLOGO PARA INSCREVER NOVO ADMINISTRADOR
  void _abrirDialogoNovoAdmin(StateSetter setDialogState) {
    TextEditingController novoNomeController = TextEditingController();
    TextEditingController novaSenhaController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cadastrar Novo Administrador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: novoNomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Administrador',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: novaSenhaController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Senha / PIN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF384959), foregroundColor: Colors.white),
              onPressed: () {
                String nome = novoNomeController.text.trim();
                String pin = novaSenhaController.text.trim();

                if (nome.isNotEmpty && pin.isNotEmpty) {
                  setDialogState(() {
                    _listaAdmins.add(AdminModel(nome: nome, pin: pin));
                  });
                  setState(() {});

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Administrador "$nome" cadastrado com sucesso!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preencha o nome e a senha!'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Cadastrar'),
            ),
          ],
        );
      },
    );
  }

  // DIÁLOGO PRINCIPAL DE ADMIN / LOGIN / GERENCIAMENTO
  void _abrirDialogoAdmin() {
    TextEditingController pinController = TextEditingController();
    int adminSelecionadoIndex = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Color(0xFF384959)),
                  const SizedBox(width: 8),
                  Text(_eAdmin ? 'Gerenciar Administradores' : 'Acesso Restrito - Admin'),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: _eAdmin
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Conectado como: $_adminLogado',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Administradores Cadastrados:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF384959),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                onPressed: () => _abrirDialogoNovoAdmin(setDialogState),
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('+ Inscrever Admin', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              itemCount: _listaAdmins.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: _listaAdmins[index].nome,
                                          decoration: const InputDecoration(
                                            labelText: 'Nome',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) => _listaAdmins[index].nome = val,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 110,
                                        child: TextFormField(
                                          initialValue: _listaAdmins[index].pin,
                                          decoration: const InputDecoration(
                                            labelText: 'Senha / PIN',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          obscureText: true,
                                          onChanged: (val) => _listaAdmins[index].pin = val,
                                        ),
                                      ),
                                      if (_listaAdmins.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () {
                                            setDialogState(() {
                                              _listaAdmins.removeAt(index);
                                            });
                                            setState(() {});
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Selecione seu nome e digite sua senha de Administrador:'),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            value: adminSelecionadoIndex < _listaAdmins.length ? adminSelecionadoIndex : 0,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(), 
                              labelText: 'Administrador'
                            ),
                            items: List.generate(_listaAdmins.length, (index) {
                              return DropdownMenuItem(
                                value: index,
                                child: Text(_listaAdmins[index].nome.isEmpty ? 'Admin ${index + 1}' : _listaAdmins[index].nome),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => adminSelecionadoIndex = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: pinController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'PIN / Senha',
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                if (_eAdmin) ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _eAdmin = false;
                        _adminLogado = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Sair do Modo Admin', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text('Salvar Alterações'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF384959), foregroundColor: Colors.white),
                    onPressed: () {
                      String pinDigitado = pinController.text.trim();
                      String pinCorreto = _listaAdmins[adminSelecionadoIndex].pin;

                      if (pinCorreto.isNotEmpty && pinDigitado == pinCorreto) {
                        setState(() {
                          _eAdmin = true;
                          _adminLogado = _listaAdmins[adminSelecionadoIndex].nome;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Bem-vindo, $_adminLogado! Modo Admin ativado.')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN/Senha incorreto!'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('Entrar'),
                  ),
                ]
              ],
            );
          },
        );
      },
    );
  }

  List<String> _obterListaIrmaos(int colunaIndex) {
    List<String> lista = [];
    for (int i = 0; i < 15; i++) {
      String nome = _controladoresDirigentes[i][colunaIndex].text.trim();
      if (nome.isNotEmpty) {
        lista.add(nome);
      }
    }
    return lista;
  }

  String _sortearIrmao(List<String> lista, Random random) {
    if (lista.isEmpty) return '';
    return lista[random.nextInt(lista.length)];
  }

  void _carregarOuGerarMesAtual() {
    if (!_cacheServicoCampo.containsKey(_mesSelecionado)) {
      _gerarCalendarioParaMes(_mesSelecionado);
    }
    setState(() {});
  }

  void _gerarCalendarioParaMes(int mes) {
    List<String> irmaosSegASexta = _obterListaIrmaos(0);
    List<String> irmaosSabEDom = _obterListaIrmaos(1);
    List<String> irmaosSoDomingo = _obterListaIrmaos(2);

    List<String> irmaosTodosDomingo = [...irmaosSabEDom, ...irmaosSoDomingo];

    Random random = Random();
    int totalDiasNoMes = DateTime(_anoSelecionado, mes + 1, 0).day;

    List<List<TextEditingController>> novasLinhas = [];

    for (int dia = 1; dia <= totalDiasNoMes; dia++) {
      DateTime data = DateTime(_anoSelecionado, mes, dia);
      int weekday = data.weekday;

      String diaStr = '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}';
      String semanaStr = _diasDaSemanaTexto[weekday - 1];
      String horarioStr = (weekday == 4) ? '17:30' : '08:30';
      String localStr = _locaisPadraoPorDiaDaSemana[weekday] ?? '';

      String dirigenteSorteado = '';
      if (weekday >= 1 && weekday <= 5) {
        dirigenteSorteado = _sortearIrmao(irmaosSegASexta, random);
      } else if (weekday == 6) {
        dirigenteSorteado = _sortearIrmao(irmaosSabEDom, random);
      } else if (weekday == 7) {
        dirigenteSorteado = _sortearIrmao(irmaosTodosDomingo, random);
      }

      novasLinhas.add([
        TextEditingController(text: diaStr),
        TextEditingController(text: semanaStr),
        TextEditingController(text: horarioStr),
        TextEditingController(text: localStr),
        TextEditingController(text: dirigenteSorteado),
      ]);
    }

    _cacheServicoCampo[mes] = novasLinhas;
  }

  void _replicarLocaisParaTodosOsMeses() {
    List<List<TextEditingController>>? linhasMesAtual = _cacheServicoCampo[_mesSelecionado];
    if (linhasMesAtual == null) return;

    for (int dia = 1; dia <= linhasMesAtual.length; dia++) {
      DateTime data = DateTime(_anoSelecionado, _mesSelecionado, dia);
      int weekday = data.weekday;
      String localAtual = linhasMesAtual[dia - 1][3].text.trim();

      if (localAtual.isNotEmpty) {
        _locaisPadraoPorDiaDaSemana[weekday] = localAtual;
      }
    }

    for (int m = 1; m <= 12; m++) {
      if (!_cacheServicoCampo.containsKey(m)) {
        _gerarCalendarioParaMes(m);
      } else {
        List<List<TextEditingController>> linhasDoMes = _cacheServicoCampo[m]!;
        for (int dia = 1; dia <= linhasDoMes.length; dia++) {
          DateTime data = DateTime(_anoSelecionado, m, dia);
          int weekday = data.weekday;
          if (_locaisPadraoPorDiaDaSemana.containsKey(weekday)) {
            linhasDoMes[dia - 1][3].text = _locaisPadraoPorDiaDaSemana[weekday]!;
          }
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Locais de saída replicados para todos os meses com sucesso!')),
    );

    setState(() {});
  }

  void _selecionarImagemWeb() {
    if (!_eAdmin) return;
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();

        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((event) {
          setState(() {
            _bytesImagemTerritorio = reader.result as Uint8List?;
          });
        });
      }
    });
  }

  Color _obterCorQuadra(int estado) {
    switch (estado) {
      case 1:
        return Colors.yellow.shade600;
      case 2:
        return Colors.green.shade600;
      default:
        return Colors.transparent;
    }
  }

  @override
  void dispose() {
    _controllerLocal.dispose();
    _controllerTerritorioNum.dispose();
    for (var linha in _controladoresRegistros) {
      for (var controller in linha) {
        controller.dispose();
      }
    }
    _cacheServicoCampo.forEach((_, tabela) {
      for (var linha in tabela) {
        for (var controller in linha) {
          controller.dispose();
        }
      }
    });
    for (var linha in _controladoresDirigentes) {
      for (var controller in linha) {
        controller.dispose();
      }
    }
    for (var linha in _controladoresNomesEventos) {
      for (var controller in linha) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Território de Congregação'),
        centerTitle: true,
        backgroundColor: const Color(0xFF384959),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                _eAdmin ? Icons.admin_panel_settings : Icons.lock_outline,
                size: 18,
                color: _eAdmin ? Colors.green : Colors.grey[700],
              ),
              label: Text(
                _eAdmin ? 'Admin: $_adminLogado' : 'Entrar Admin',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: _abrirDialogoAdmin,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBotaoMenu(0, Icons.map, 'Territórios'),
                _buildBotaoMenu(1, Icons.menu_book, 'Serviço de Campo'),
                _buildBotaoMenu(2, Icons.event, 'Eventos'),
                _buildBotaoMenu(3, Icons.person, 'Dirigente'),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildConteudoAba(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoMenu(int index, IconData icon, String label) {
    bool selecionado = _abaSelecionada == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: selecionado ? const Color(0xFF384959) : Colors.white,
          foregroundColor: selecionado ? Colors.white : Colors.black87,
          elevation: selecionado ? 4 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setState(() {
            _abaSelecionada = index;
            _territorioSelecionado = null;
          });
        },
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildConteudoAba() {
    switch (_abaSelecionada) {
      case 0:
        return _buildAbaTerritorios();
      case 1:
        return _buildAbaServicoCampo();
      case 2:
        return _buildAbaEventos();
      case 3:
        return _buildAbaDirigente();
      default:
        return Container();
    }
  }

  Widget _buildAbaEventos() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF384959),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ESCALA DE EVENTOS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                if (!_eAdmin) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock, color: Colors.white54, size: 16),
                ]
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 45,
              dataRowHeight: 45,
              columnSpacing: 10,
              headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
              border: TableBorder.all(color: Colors.black, width: 1),
              columns: const [
                DataColumn(label: SizedBox(width: 120, child: Text('NOME', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                DataColumn(label: SizedBox(width: 140, child: Text('DIAS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                DataColumn(label: SizedBox(width: 120, child: Text('NOME', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                DataColumn(label: SizedBox(width: 140, child: Text('DIAS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                DataColumn(label: SizedBox(width: 120, child: Text('NOME', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                DataColumn(label: SizedBox(width: 140, child: Text('DIAS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                DataColumn(label: SizedBox(width: 120, child: Text('NOME', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                DataColumn(label: SizedBox(width: 140, child: Text('DIAS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              ],
              rows: List.generate(14, (rowIndex) {
                return DataRow(
                  cells: List.generate(8, (colIndex) {
                    bool isColunaNome = colIndex % 2 == 0;
                    int blocoIndex = colIndex ~/ 2;

                    if (isColunaNome) {
                      int numero = (blocoIndex * 14) + (rowIndex + 1);
                      String numStr = numero.toString().padLeft(2, '0');

                      return DataCell(
                        SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              Text('$numStr. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                              Expanded(
                                child: TextField(
                                  readOnly: !_eAdmin,
                                  controller: _controladoresNomesEventos[rowIndex][blocoIndex],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                    hintText: 'Nome...',
                                    hintStyle: TextStyle(color: Colors.black38, fontSize: 11),
                                  ),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      Set<String> diasAtivos = _diasSelecionadosEventos[rowIndex][blocoIndex];

                      return DataCell(
                        SizedBox(
                          width: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildOpcaoDia('Sexta', diasAtivos.contains('Sexta'), () {
                                if (!_eAdmin) return;
                                setState(() {
                                  diasAtivos.contains('Sexta') ? diasAtivos.remove('Sexta') : diasAtivos.add('Sexta');
                                });
                              }),
                              _buildOpcaoDia('Sáb', diasAtivos.contains('Sábado'), () {
                                if (!_eAdmin) return;
                                setState(() {
                                  diasAtivos.contains('Sábado') ? diasAtivos.remove('Sábado') : diasAtivos.add('Sábado');
                                });
                              }),
                              _buildOpcaoDia('Dom', diasAtivos.contains('Domingo'), () {
                                if (!_eAdmin) return;
                                setState(() {
                                  diasAtivos.contains('Domingo') ? diasAtivos.remove('Domingo') : diasAtivos.add('Domingo');
                                });
                              }),
                            ],
                          ),
                        ),
                      );
                    }
                  }),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcaoDia(String label, bool selecionado, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFF384959) : Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selecionado ? const Color(0xFF384959) : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
            color: selecionado ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildAbaServicoCampo() {
    List<List<TextEditingController>> linhasAtuais = _cacheServicoCampo[_mesSelecionado] ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.grey[100],
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Mês: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: _mesSelecionado,
                        items: List.generate(12, (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(_nomesMeses[index]),
                          );
                        }),
                        onChanged: (novoMes) {
                          if (novoMes != null) {
                            setState(() {
                              _mesSelecionado = novoMes;
                              _carregarOuGerarMesAtual();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Ano: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: _anoSelecionado,
                        items: List.generate(5, (index) {
                          int ano = DateTime.now().year - 1 + index;
                          return DropdownMenuItem(
                            value: ano,
                            child: Text('$ano'),
                          );
                        }),
                        onChanged: _eAdmin ? (novoAno) {
                          if (novoAno != null) {
                            setState(() {
                              _anoSelecionado = novoAno;
                              _cacheServicoCampo.clear();
                              _carregarOuGerarMesAtual();
                            });
                          }
                        } : null,
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF384959),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _eAdmin ? () {
                      _gerarCalendarioParaMes(_mesSelecionado);
                      setState(() {});
                    } : null,
                    icon: const Icon(Icons.autorenew, size: 18),
                    label: const Text('Sortear / Gerar Programação'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _eAdmin ? _replicarLocaisParaTodosOsMeses : null,
                    icon: const Icon(Icons.copy_all, size: 18),
                    label: const Text('Replicar Saídas p/ Todos os Meses'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[300],
            child: Text(
              'Programação do serviço de campo do mês de ${_nomesMeses[_mesSelecionado - 1]} de $_anoSelecionado',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowHeight: 38,
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
              border: TableBorder.all(color: Colors.grey.shade400, width: 1),
              columns: const [
                DataColumn(label: Text('Dia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                DataColumn(label: Text('Semana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                DataColumn(label: Text('Horário', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                DataColumn(label: Text('Local de saída', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                DataColumn(label: Text('Dirigente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ],
              rows: List.generate(linhasAtuais.length, (rowIndex) {
                return DataRow(
                  cells: [
                    _buildCellTextField(linhasAtuais[rowIndex][0], width: 60, readOnly: !_eAdmin),
                    _buildCellTextField(linhasAtuais[rowIndex][1], width: 110, readOnly: !_eAdmin),
                    _buildCellTextField(linhasAtuais[rowIndex][2], width: 70, readOnly: !_eAdmin),
                    _buildCellTextField(linhasAtuais[rowIndex][3], width: 180, readOnly: !_eAdmin),
                    _buildCellTextField(linhasAtuais[rowIndex][4], width: 180, readOnly: !_eAdmin),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Romanos 10:15 – "... Assim como está escrito: “Como são lindos os pés daqueles que declaram boas novas de coisas boas!”"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataCell _buildCellTextField(TextEditingController controller, {required double width, bool readOnly = false}) {
    return DataCell(
      SizedBox(
        width: width,
        child: TextField(
          readOnly: readOnly,
          controller: controller,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          ),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildAbaDirigente() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF384959),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'RELAÇÃO DE DIRIGENTES DO SERVIÇO DE CAMPO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                if (!_eAdmin) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock, color: Colors.white54, size: 16),
                ]
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 45,
              dataRowHeight: 40,
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
              border: TableBorder.all(color: Colors.black, width: 1),
              columns: const [
                DataColumn(
                  label: SizedBox(
                    width: 180,
                    child: Text(
                      'Segunda a Sexta',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 180,
                    child: Text(
                      'Sábado e Domingo',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: 180,
                    child: Text(
                      'Domingo',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
              rows: List.generate(15, (rowIndex) {
                return DataRow(
                  cells: List.generate(3, (colIndex) {
                    return DataCell(
                      SizedBox(
                        width: 180,
                        child: TextField(
                          readOnly: !_eAdmin,
                          controller: _controladoresDirigentes[rowIndex][colIndex],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            hintText: 'Nome do irmão...',
                            hintStyle: TextStyle(color: Colors.black38, fontSize: 12),
                          ),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaTerritorios() {
    if (_territorioSelecionado != null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _territorioSelecionado = null),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black12,
                    child: const Text(
                      'CARTÃO DE MAPA DE TERRITÓRIO',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      const Text('LOCAL: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: TextField(
                          readOnly: !_eAdmin,
                          controller: _controllerLocal,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Text('TERR: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: TextField(
                          readOnly: !_eAdmin,
                          controller: _controllerTerritorioNum,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _eAdmin ? _selecionarImagemWeb : null,
              child: Container(
                height: 350,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  color: _bytesImagemTerritorio != null ? Colors.black87 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _bytesImagemTerritorio != null
                      ? Image.memory(
                          _bytesImagemTerritorio!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo, size: 56, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              _eAdmin ? 'Clique para carregar a foto do Mapa' : 'Imagem do Mapa (Apenas Admin pode alterar)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 35,
                dataRowHeight: 40,
                border: TableBorder.all(color: Colors.black, width: 1),
                columns: const [
                  DataColumn(label: Text('DIRIGENTE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('PUBL', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DIRIGENTE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('PUBL', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATA INICIAL', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(8, (rowIndex) {
                  return DataRow(
                    cells: List.generate(7, (colIndex) {
                      return DataCell(
                        SizedBox(
                          width: 80,
                          child: TextField(
                            readOnly: false,
                            controller: _controladoresRegistros[rowIndex][colIndex],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4),
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(6),
              color: Colors.grey[300],
              child: const Text(
                'NÚMERO DAS QUADRAS / CLIQUE PARA MUDAR A COR (AMARELO / VERDE)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 35,
                dataRowHeight: 40,
                horizontalMargin: 8,
                columnSpacing: 10,
                border: TableBorder.all(color: Colors.black, width: 1),
                columns: List.generate(14, (index) {
                  return DataColumn(
                    label: SizedBox(
                      width: 28,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
                rows: List.generate(8, (rowIndex) {
                  return DataRow(
                    cells: List.generate(14, (colIndex) {
                      int estadoAtual = _estadoQuadras[rowIndex][colIndex];
                      return DataCell(
                        InkWell(
                          onTap: () {
                            setState(() {
                              _estadoQuadras[rowIndex][colIndex] = (estadoAtual + 1) % 3;
                            });
                          },
                          child: Container(
                            width: 28,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _obterCorQuadra(estadoAtual),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 14,
      itemBuilder: (context, index) {
        int numTerritorio = index + 1;
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEFEFEF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            setState(() {
              _territorioSelecionado = numTerritorio;
              _controllerTerritorioNum.text = '$numTerritorio';
            });
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined),
              const SizedBox(height: 4),
              Text('Território $numTerritorio', textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}
