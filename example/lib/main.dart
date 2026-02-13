import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_effect/flutter_bloc_effect.dart';

// --- Effects ---

sealed class LoginEffect {}

class NavigateToHome extends LoginEffect {}

class ShowErrorSnackbar extends LoginEffect {
  final String message;
  ShowErrorSnackbar(this.message);
}

// --- State ---

sealed class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {}

// --- Cubit ---

class LoginCubit extends Cubit<LoginState>
    with SideEffectMixin<LoginState, LoginEffect> {
  LoginCubit() : super(LoginInitial());

  Future<void> login(String email, String password) async {
    emit(LoginLoading());

    // Simulate network request.
    await Future<void>.delayed(const Duration(seconds: 1));

    if (email == 'test@test.com' && password == 'password') {
      emit(LoginSuccess());
      emitEffect(NavigateToHome());
    } else {
      emit(LoginInitial());
      emitEffect(ShowErrorSnackbar('Invalid email or password'));
    }
  }
}

// --- App ---

void main() {
  EffectObserver.instance = _LoggingEffectObserver();
  runApp(const MyApp());
}

class _LoggingEffectObserver extends EffectObserver {
  @override
  void onEffect(BlocBase<dynamic> bloc, Object? effect) {
    debugPrint('[Effect] ${bloc.runtimeType} → $effect');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bloc_effect Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => LoginCubit(),
        child: const LoginPage(),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(text: 'test@test.com');
  final _passwordController = TextEditingController(text: 'password');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SideEffectListener<LoginCubit, LoginEffect>(
        listener: (context, effect) {
          switch (effect) {
            case NavigateToHome():
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Login successful! Would navigate to home.'),
                  backgroundColor: Colors.green,
                ),
              );
            case ShowErrorSnackbar(:final message):
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.red,
                ),
              );
          }
        },
        child: BlocBuilder<LoginCubit, LoginState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    enabled: state is! LoginLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: state is! LoginLoading,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state is LoginLoading
                          ? null
                          : () {
                              context.read<LoginCubit>().login(
                                    _emailController.text,
                                    _passwordController.text,
                                  );
                            },
                      child: state is LoginLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Use test@test.com / password',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
