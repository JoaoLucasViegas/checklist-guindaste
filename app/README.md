# App Android (Flutter)

> O projeto Flutter **não** está pré-gerado: crie-o aqui para evitar versões quebradas.

## Receita
```bash
cd app
flutter create --org br.com.copi --project-name checklist_guindaste --platforms android .
flutter pub add dio flutter_riverpod go_router drift sqlite3_flutter_libs path_provider \
  flutter_secure_storage connectivity_plus uuid intl signature
flutter pub add --dev drift_dev build_runner
flutter run
```
Se o `flutter create` sobrescrever este README, recupere com `git checkout app/README.md`.
Depois, mova as pastas de `lib_planejado/` para dentro de `lib/` (ou renomeie) e siga a estrutura abaixo.

## Android: rede no APK de release (FE-14)
O manifest principal já declara `INTERNET` e permite HTTP simples (`usesCleartextTraffic`) para a demo local. Essa permissão de HTTP é ampla: use somente em builds de demonstração numa rede confiável e remova-a quando a API estiver em HTTPS.

Em aparelho físico, `10.0.2.2` não aponta para o notebook. Informe o IP do computador na rede:
```bash
cd app
flutter build apk --release --dart-define=API_URL=http://192.168.0.15:8000/api/v1
```
Teste o APK instalado em aparelho real; `flutter run` sozinho não valida o build de release.

## Estrutura de `lib/`
```
core/               tema, rotas, cliente HTTP, config (URL do servidor lida de configuração, não do código)
data/local/         banco local (drift): template, lookups, checklists, fila de sincronização
data/remote/        cliente da API
data/repositories/  ÚNICO ponto que decide local x remoto (telas nunca chamam a API direto)
domain/             modelos e regras (validações RN01–RN06, lote RN12) + testes
features/auth       login único; o perfil vem da resposta da API
features/home       home do operador
features/checklist_form  cabeçalho, itens, finalização, assinatura, edição
features/admin      lista, detalhe completo, vistar, solicitar correção
sync/               fila offline e reenvio
```

## Regras
- **URL do servidor configurável** (tela de configurações ou `--dart-define=API_URL=...`). Sem recompilar para trocar.
- **Modo mock** por flag, para trabalhar antes do back-end ficar pronto.
- Pacotes: confira versão e atualização no pub.dev antes de adicionar algo novo.
- Keystore/senha de assinatura **fora do Git**.
