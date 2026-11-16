# MotoGest

Aplicação Android offline para registo manual de ganhos e despesas, com SQLite local, histórico, relatórios e cópias de segurança.

## Gerar APK pelo GitHub

1. Crie uma conta em https://github.com/ (se ainda não tiver).
2. Crie um repositório chamado `motogest`.
3. Extraia o ZIP deste projeto no computador.
4. No repositório, escolha **Add file > Upload files** e envie todos os ficheiros e pastas extraídos, incluindo a pasta oculta `.github`.
5. Faça **Commit changes** na branch `main`.
6. Abra o separador **Actions** do repositório.
7. Escolha **Build MotoGest APK** e carregue em **Run workflow**. Também pode iniciar automaticamente após um push na `main`.
8. Aguarde o workflow terminar com o visto verde. Se falhar, abra a execução e consulte o primeiro passo com erro.
9. Abra a execução concluída, desça até **Artifacts** e descarregue `MotoGest-APK`.
10. Extraia o ZIP descarregado. Dentro estará `app-release.apk`.
11. Envie o APK para o telefone Android e instale-o. Poderá ser necessário autorizar a instalação de aplicações desta origem nas definições do Android.

## O que está incluído

- Painel de ganhos, despesas e lucro do dia.
- Registo de ganhos e despesas, com categorias, data, descrição e observações.
- Edição e eliminação de movimentos.
- Histórico com filtros por tipo.
- Relatórios diários, semanais e mensais com gráfico.
- Exportação e restauração de cópia de segurança JSON.
- Dados guardados localmente em SQLite.

## Notas importantes

- Não necessita de conta, API, Firebase ou internet para as funções de gestão.
- A primeira compilação é feita pelos servidores GitHub Actions e necessita de internet durante a compilação.
- A cópia de segurança deve ser exportada regularmente. Desinstalar a aplicação ou limpar os dados do Android pode apagar a base de dados local.
- Antes de publicar para muitos utilizadores, faça testes em vários telefones Android e valide especialmente exportação/restauração e relatórios.
