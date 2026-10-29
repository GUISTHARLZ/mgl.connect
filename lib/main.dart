import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const navy = Color(0xFF0C152A),
    panel = Color(0xFF17233B),
    teal = Color(0xFF79B6B6),
    muted = Color(0xFF98A3B5);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: navy,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: navy,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MglApp());
}

class MglApp extends StatelessWidget {
  const MglApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'M.G.L Connect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: navy,
          colorScheme: const ColorScheme.dark(
            primary: teal,
            secondary: teal,
            surface: panel,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: navy,
            foregroundColor: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF29354E),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF3A4760)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: teal, width: 1.5),
            ),
          ),
        ),
        home: LoginPage(repo: Repo.create()),
      );
}

enum Status {
  pending('Pendente', Color(0xFFFFC76A)),
  transit('Em transporte', Color(0xFF8EC8FF)),
  delivered('Entregue', Color(0xFF8ED6B0));

  const Status(this.label, this.color);
  final String label;
  final Color color;
  static Status parse(Object? v) {
    final s = v.toString().toLowerCase();
    if (s.contains('entregue')) return delivered;
    if (s.contains('transporte') || s.contains('transit')) return transit;
    return pending;
  }
}

class Session {
  const Session(this.id, this.name, [this.token]);
  final String id, name;
  final String? token;
}

class Delivery {
  const Delivery(this.id, this.order, this.customer, this.address, this.status);
  final String id, order, customer, address;
  final Status status;
  Delivery withStatus(Status v) => Delivery(id, order, customer, address, v);
  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
        (j['id'] ?? j['entregaId'] ?? '').toString(),
        (j['pedido'] ?? j['numeroPedido'] ?? '').toString(),
        (j['cliente'] ?? j['nomeCliente'] ?? '').toString(),
        (j['endereco'] ?? j['enderecoCompleto'] ?? '').toString(),
        Status.parse(j['status']),
      );
}

abstract class Repo {
  Future<Session> login(String user, String pass);
  Future<List<Delivery>> list(Session s);
  Future<void> update(Session s, Delivery d);
  static Repo create() {
    const url = String.fromEnvironment('API_BASE_URL');
    return url.isEmpty ? DemoRepo() : ApiRepo(url);
  }
}

class DemoRepo implements Repo {
  final items = <Delivery>[
    const Delivery(
      '1001',
      'ABC-123',
      'Mariana Costa',
      'Rua das Palmeiras, 123 - Centro, Santos - SP, CEP 11010-000',
      Status.pending,
    ),
    const Delivery(
      '1002',
      'ABC-124',
      'Rafael Mendes',
      'Av. Conselheiro Nébias, 640 - Boqueirão, Santos - SP, CEP 11045-002',
      Status.transit,
    ),
    const Delivery(
      '1003',
      'ABC-125',
      'Cláudia Ribeiro',
      'Rua Goiás, 87 - Gonzaga, Santos - SP, CEP 11050-100',
      Status.pending,
    ),
    const Delivery(
      '1004',
      'ABC-126',
      'Lucas Ferreira',
      'Av. Ana Costa, 355 - Vila Mathias, Santos - SP, CEP 11060-001',
      Status.delivered,
    ),
  ];
  @override
  Future<Session> login(String user, String pass) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final n = user.trim().isEmpty ? 'Carlos' : user.trim();
    return Session('demo', n[0].toUpperCase() + n.substring(1));
  }

  @override
  Future<List<Delivery>> list(Session s) async => List.unmodifiable(items);
  @override
  Future<void> update(Session s, Delivery d) async {
    final i = items.indexWhere((x) => x.id == d.id);
    if (i >= 0) items[i] = d;
  }
}

class ApiRepo implements Repo {
  ApiRepo(String url) : base = Uri.parse(url.endsWith('/') ? url : '$url/');
  final Uri base;
  final HttpClient client = HttpClient();
  Future<dynamic> req(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final r = await client.openUrl(method, base.resolve(path));
    r.headers.contentType = ContentType.json;
    if (token != null && token.isNotEmpty) {
      r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) r.write(jsonEncode(body));
    final response = await r.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'A API retornou HTTP ${response.statusCode}.',
      );
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  @override
  Future<Session> login(String user, String pass) async {
    final j = await req(
      'POST',
      'api/auth/login',
      body: {'usuario': user, 'senha': pass},
    ) as Map<String, dynamic>;
    return Session(
      (j['motoristaId'] ?? j['id']).toString(),
      (j['nome'] ?? j['name'] ?? user).toString(),
      j['token']?.toString(),
    );
  }

  @override
  Future<List<Delivery>> list(Session s) async {
    final j = await req(
      'GET',
      'api/motoristas/${Uri.encodeComponent(s.id)}/entregas',
      token: s.token,
    );
    final a = j is List ? j : (j['items'] as List? ?? <dynamic>[]);
    return a
        .map((x) => Delivery.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
  }

  @override
  Future<void> update(Session s, Delivery d) async {
    await req(
      'PUT',
      'api/entregas/${Uri.encodeComponent(d.id)}/status',
      token: s.token,
      body: {'status': d.status.label},
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.repo});
  final Repo repo;
  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  final form = GlobalKey<FormState>(),
      user = TextEditingController(),
      pass = TextEditingController();
  bool visible = false, loading = false;
  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> enter() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final s = await widget.repo.login(user.text.trim(), pass.text);
      var items = <Delivery>[];
      String? loadError;
      try {
        items = await widget.repo.list(s);
      } catch (_) {
        loadError =
            'Não foi possível conectar ao banco de dados da empresa. Verifique sua conexão e tente novamente.';
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ListPage(
            repo: widget.repo,
            session: s,
            items: items,
            loadError: loadError,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível entrar. ${errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const Center(child: Brand()),
                      const SizedBox(height: 62),
                      const Text(
                        'Acesse sua conta',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: user,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe seu usuário.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: pass,
                        obscureText: !visible,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => enter(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip:
                                visible ? 'Ocultar senha' : 'Mostrar senha',
                            onPressed: () => setState(() => visible = !visible),
                            icon: Icon(
                              visible ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Informe sua senha.'
                            : null,
                      ),
                      const SizedBox(height: 30),
                      FilledButton(
                        onPressed: loading ? null : enter,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF34777A),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Entrar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'M.G.L Connect • Área do motorista',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class ListPage extends StatefulWidget {
  const ListPage({
    super.key,
    required this.repo,
    required this.session,
    required this.items,
    this.loadError,
  });
  final Repo repo;
  final Session session;
  final List<Delivery> items;
  final String? loadError;
  @override
  State<ListPage> createState() => _ListState();
}

class _ListState extends State<ListPage> {
  late final items = List<Delivery>.of(widget.items);
  late String? loadError = widget.loadError;
  bool loading = false;

  Future<void> reload() async {
    setState(() => loading = true);
    try {
      final refreshedItems = await widget.repo.list(widget.session);
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(refreshedItems);
        loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loadError =
              'Não foi possível conectar ao banco de dados da empresa. Verifique sua conexão e tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = items.where((x) => x.status == Status.delivered).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas entregas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute<void>(
                builder: (_) => LoginPage(repo: widget.repo),
              ),
              (_) => false,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Olá, ${widget.session.name}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3953)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: teal.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: teal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${items.length} pedidos na sua lista',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$done entregues',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Entregas atribuídas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (loadError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF493A2A),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Status.pending.color),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loadError!,
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: loading ? null : reload,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          if (items.isEmpty && loadError == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Nenhuma entrega atribuída no momento.'),
              ),
            ),
          for (final d in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CardDelivery(
                d: d,
                onTap: () async {
                  final updated = await Navigator.push<Delivery>(
                    context,
                    MaterialPageRoute<Delivery>(
                      builder: (_) => DetailPage(
                        repo: widget.repo,
                        session: widget.session,
                        d: d,
                      ),
                    ),
                  );
                  if (updated != null && mounted) {
                    setState(() {
                      final i = items.indexWhere(
                        (x) => x.id == updated.id,
                      );
                      if (i >= 0) items[i] = updated;
                    });
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class CardDelivery extends StatelessWidget {
  const CardDelivery({super.key, required this.d, required this.onTap});
  final Delivery d;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: d.status.color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: d.status.color.withValues(alpha: .4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pedido ${d.order}',
                      style: const TextStyle(
                        color: teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  d.customer,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 13),
                ChipStatus(status: d.status),
              ],
            ),
          ),
        ),
      );
}

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.repo,
    required this.session,
    required this.d,
  });
  final Repo repo;
  final Session session;
  final Delivery d;
  @override
  State<DetailPage> createState() => _DetailState();
}

class _DetailState extends State<DetailPage> {
  late Status selected = widget.d.status;
  bool saving = false;
  Future<void> save() async {
    if (selected == widget.d.status) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um status diferente para atualizar.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Confirmar atualização'),
        content: Text(
          'Alterar o pedido ${widget.d.order} para “${selected.label}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => saving = true);
    final updated = widget.d.withStatus(selected);
    try {
      await widget.repo.update(widget.session, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido ${updated.order} atualizado para ${updated.status.label.toLowerCase()}',
          ),
        ),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível atualizar. ${errorText(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detalhes da entrega')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido ${widget.d.order}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: teal,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ChipStatus(status: widget.d.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.d.customer,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 22),
            PanelInfo(
              icon: Icons.location_on_outlined,
              title: 'Endereço de destino',
              child: Text(
                widget.d.address,
                style: const TextStyle(
                  color: Color(0xFFD6DCE5),
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Atualizar status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecione a situação atual do pedido.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (final s in Status.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: panel,
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    onTap: () => setState(() => selected = s),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: selected == s
                              ? teal.withValues(alpha: .7)
                              : const Color(0xFF293750),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected == s
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected == s ? teal : muted,
                            size: 20,
                          ),
                          const SizedBox(width: 11),
                          Text(
                            s.label,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Atualizar status'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25595D),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
}

class PanelInfo extends StatelessWidget {
  const PanelInfo({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF293750)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: teal),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class ChipStatus extends StatelessWidget {
  const ChipStatus({super.key, required this.status});
  final Status status;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: const Size(48, 48), painter: HexLogo()),
          const SizedBox(width: 12),
          const Text(
            'M.G.L CONNECT',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
}

class HexLogo extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    void hex(double r, Color color) {
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = (i * 60 - 30) * math.pi / 180;
        final o = Offset(
          center.dx + r * math.cos(a),
          center.dy + r * math.sin(a),
        );
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      c.drawPath(p..close(), Paint()..color = color);
    }

    hex(23, const Color(0xFFDCE7EB));
    hex(15, navy);
    hex(7, teal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String errorText(Object e) {
  if (e is SocketException) return 'Verifique a conexão com a API.';
  if (e is HttpException) return e.message;
  return 'Tente novamente em instantes.';
}
